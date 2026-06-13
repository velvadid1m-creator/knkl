import Foundation
import UserNotifications

// MARK: - Repeat unit

enum RepeatUnit: String, Codable, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours
    case days

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        case .hours:   return 3600
        case .days:    return 86400
        }
    }

    var label: String {
        switch self {
        case .seconds: return "seconds"
        case .minutes: return "minutes"
        case .hours:   return "hours"
        case .days:    return "days"
        }
    }
}

// MARK: - Reminder model

struct Reminder: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var soundName: String = "chime.wav"   // "" == system default
    var every: Int = 1
    var unit: RepeatUnit = .hours
    var isOn: Bool = true

    /// Gap between normal alerts — random between min and max seconds.
    var spacingMinSeconds: Int = 120
    var spacingMaxSeconds: Int = 10800

    /// Fast cluster of alerts, separated by longer gaps.
    var burstEnabled: Bool = false
    /// Milliseconds between dings inside a burst — 0 = as fast as iOS allows.
    var burstMinMilliseconds: Int = 0
    var burstMaxMilliseconds: Int = 0
    var burstCount: Int = 4
    var burstEvery: Int = 20
    var burstEveryUnit: RepeatUnit = .minutes

    var intervalSeconds: TimeInterval {
        Double(max(1, every)) * unit.seconds
    }

    var burstEverySeconds: TimeInterval {
        Double(max(1, burstEvery)) * burstEveryUnit.seconds
    }

    var normalizedSpacingSeconds: (min: Int, max: Int) {
        let minValue = max(1, min(spacingMinSeconds, spacingMaxSeconds))
        let maxValue = max(minValue, max(spacingMinSeconds, spacingMaxSeconds))
        return (minValue, maxValue)
    }

    var normalizedBurstMilliseconds: (min: Int, max: Int) {
        let minValue = max(0, min(burstMinMilliseconds, burstMaxMilliseconds))
        let maxValue = max(minValue, max(burstMinMilliseconds, burstMaxMilliseconds))
        return (minValue, maxValue)
    }

    static func formatBurstGapMilliseconds(_ milliseconds: Int) -> String {
        if milliseconds <= 0 { return "instant" }
        if milliseconds < 1000 { return "\(milliseconds)ms" }
        if milliseconds % 1000 == 0 { return "\(milliseconds / 1000)s" }
        return String(format: "%.2fs", Double(milliseconds) / 1000)
    }

    static func formatBurstGapRangeMilliseconds(min: Int, max: Int) -> String {
        if min <= 0 && max <= 0 { return "instant" }
        if min == max { return formatBurstGapMilliseconds(min) }
        return "\(formatBurstGapMilliseconds(min))–\(formatBurstGapMilliseconds(max))"
    }

    static func formatBurstGap(_ seconds: Double) -> String {
        formatBurstGapMilliseconds(Int((seconds * 1000).rounded()))
    }

    static func formatBurstGapRange(min: Double, max: Double) -> String {
        formatBurstGapRangeMilliseconds(
            min: Int((min * 1000).rounded()),
            max: Int((max * 1000).rounded())
        )
    }

    static func formatDuration(_ seconds: Int) -> String {
        let value = max(1, seconds)
        if value < 60 { return "\(value)s" }
        if value < 3600 {
            let m = value / 60
            let s = value % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        let h = value / 3600
        let m = (value % 3600) / 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var cadenceText: String {
        let (spacingLo, spacingHi) = normalizedSpacingSeconds
        if burstEnabled {
            let (burstLo, burstHi) = normalizedBurstMilliseconds
            let burstUnit = burstEveryUnit.label
            let burstWord = burstEvery == 1 ? String(burstUnit.dropLast()) : burstUnit
            let burstGap = Reminder.formatBurstGapRangeMilliseconds(min: burstLo, max: burstHi)
            return "Varied \(Reminder.formatDuration(spacingLo))–\(Reminder.formatDuration(spacingHi)) · burst \(burstCount)× (\(burstGap)) every ~\(burstEvery) \(burstWord)"
        }
        if usesDynamicText || spacingLo != spacingHi {
            return "Varied \(Reminder.formatDuration(spacingLo))–\(Reminder.formatDuration(spacingHi))"
        }
        let word: String
        switch unit {
        case .seconds: word = every == 1 ? "second" : "seconds"
        case .minutes: word = every == 1 ? "minute" : "minutes"
        case .hours:   word = every == 1 ? "hour" : "hours"
        case .days:    word = every == 1 ? "day" : "days"
        }
        return "Every \(every) \(word)"
    }

    var usesDynamicText: Bool {
        NotificationTemplate.isDynamic(title) || NotificationTemplate.isDynamic(body)
    }

    /// UK Shopify format — Order # title, price + items + source, store on next line.
    static let shopifyOrder = Reminder(
        title: "Order #{order}",
        body: "{total}, {items_phrase} from {source} •\n{store}",
        soundName: "ding.wav",
        every: 5,
        unit: .minutes,
        isOn: true,
        spacingMinSeconds: 120,
        spacingMaxSeconds: 10800,
        burstEnabled: true,
        burstMinMilliseconds: 0,
        burstMaxMilliseconds: 0,
        burstCount: 4,
        burstEvery: 20,
        burstEveryUnit: .minutes
    )
}

extension Reminder: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, body, soundName, every, unit, isOn
        case spacingMinSeconds, spacingMaxSeconds
        case burstEnabled, burstMinMilliseconds, burstMaxMilliseconds
        case burstCount, burstEvery, burstEveryUnit
        case burstMinSeconds, burstMaxSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? "chime.wav"
        every = try container.decodeIfPresent(Int.self, forKey: .every) ?? 1
        unit = try container.decodeIfPresent(RepeatUnit.self, forKey: .unit) ?? .hours
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? true
        spacingMinSeconds = try container.decodeIfPresent(Int.self, forKey: .spacingMinSeconds) ?? 120
        spacingMaxSeconds = try container.decodeIfPresent(Int.self, forKey: .spacingMaxSeconds) ?? 10800
        burstEnabled = try container.decodeIfPresent(Bool.self, forKey: .burstEnabled) ?? false
        if let minMs = try container.decodeIfPresent(Int.self, forKey: .burstMinMilliseconds) {
            burstMinMilliseconds = max(0, minMs)
        } else if let minSec = try container.decodeIfPresent(Double.self, forKey: .burstMinSeconds) {
            burstMinMilliseconds = max(0, Int((minSec * 1000).rounded()))
        } else {
            burstMinMilliseconds = 0
        }
        if let maxMs = try container.decodeIfPresent(Int.self, forKey: .burstMaxMilliseconds) {
            burstMaxMilliseconds = max(0, maxMs)
        } else if let maxSec = try container.decodeIfPresent(Double.self, forKey: .burstMaxSeconds) {
            burstMaxMilliseconds = max(0, Int((maxSec * 1000).rounded()))
        } else {
            burstMaxMilliseconds = burstMinMilliseconds
        }
        burstCount = try container.decodeIfPresent(Int.self, forKey: .burstCount) ?? 4
        burstEvery = try container.decodeIfPresent(Int.self, forKey: .burstEvery) ?? 20
        burstEveryUnit = try container.decodeIfPresent(RepeatUnit.self, forKey: .burstEveryUnit) ?? .minutes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(soundName, forKey: .soundName)
        try container.encode(every, forKey: .every)
        try container.encode(unit, forKey: .unit)
        try container.encode(isOn, forKey: .isOn)
        try container.encode(spacingMinSeconds, forKey: .spacingMinSeconds)
        try container.encode(spacingMaxSeconds, forKey: .spacingMaxSeconds)
        try container.encode(burstEnabled, forKey: .burstEnabled)
        try container.encode(burstMinMilliseconds, forKey: .burstMinMilliseconds)
        try container.encode(burstMaxMilliseconds, forKey: .burstMaxMilliseconds)
        try container.encode(burstCount, forKey: .burstCount)
        try container.encode(burstEvery, forKey: .burstEvery)
        try container.encode(burstEveryUnit, forKey: .burstEveryUnit)
    }
}

// MARK: - Template variables

struct SampleOrder {
    let itemCount: Int
    let totalPence: Int

    var itemsPhrase: String {
        itemCount == 1 ? "1 item" : "\(itemCount) items"
    }

    var totalGBP: String {
        ShopifySampleData.formatGBP(totalPence)
    }
}

enum ShopifySampleData {
    static let defaultStore = "Novus Kits"
    private static let orderNumberBase = 1134

    static func orderNumber(counter: Int) -> String {
        "\(orderNumberBase + counter)"
    }

    static func randomStore() -> String {
        defaultStore
    }

    static func randomSource() -> String {
        "Online Store"
    }

    /// Weighted 1–4 items — mostly 1–2, sometimes more.
    static func randomItemCount() -> Int {
        switch Int.random(in: 1...100) {
        case 1...38: return 1
        case 39...72: return 2
        case 73...88: return 3
        default: return 4
        }
    }

    /// One coherent order: item count + total derived from £30–£80 per item.
    static func randomOrder(perItemMinPounds: Int = 30, perItemMaxPounds: Int = 80) -> SampleOrder {
        let count = randomItemCount()
        var totalPence = 0
        for _ in 0..<count {
            totalPence += randomItemPricePence(minPounds: perItemMinPounds, maxPounds: perItemMaxPounds)
        }
        return SampleOrder(itemCount: count, totalPence: totalPence)
    }

    private static func randomItemPricePence(minPounds: Int, maxPounds: Int) -> Int {
        let pounds = Int.random(in: minPounds...maxPounds)
        let cents = [0, 0, 0, 9, 49, 53, 64, 99].randomElement() ?? 0
        return pounds * 100 + cents
    }

    static func formatGBP(_ pence: Int) -> String {
        String(format: "£%d.%02d", pence / 100, pence % 100)
    }

    /// Stable order data for dashboard rows — same counter always shows the same order.
    static func customerName(counter: Int) -> String {
        let names = ["", "Guest checkout", "James Mitchell", "Sarah Khan", "Alex Turner", "Emma Walsh"]
        return names[abs(counter) % names.count]
    }

    static func seededOrder(counter: Int) -> SampleOrder {
        let count = [1, 2, 2, 1, 2, 1, 2, 3, 1, 2][abs(counter) % 10]
        var totalPence = 0
        for index in 0..<count {
            let seed = abs(counter) &* 31 &+ index &* 17
            let pounds = 30 + (seed % 51)
            let cents = [0, 0, 9, 49, 53, 64, 99][seed % 7]
            totalPence += pounds * 100 + cents
        }
        return SampleOrder(itemCount: count, totalPence: totalPence)
    }
}

// MARK: - Dashboard data

struct DashboardOrder: Identifiable, Hashable {
    let id: Int
    let orderNumber: String
    let total: String
    let totalPence: Int
    let itemsPhrase: String
    let source: String
    let store: String
    let customer: String
    let placedAt: Date
    let status: String
    let fulfillment: String

    var subtitleLine: String {
        "\(total), \(itemsPhrase) from \(source) •"
    }

    var notificationTitle: String {
        "Order #\(orderNumber)"
    }

    var notificationBody: String {
        "\(subtitleLine)\n\(store)"
    }
}

struct DashboardStats {
    let totalSalesPence: Int
    let orderCount: Int
    let sessions: Int
    let conversionRate: Double

    var totalSales: String { ShopifySampleData.formatGBP(totalSalesPence) }
    var averageOrder: String {
        guard orderCount > 0 else { return "£0.00" }
        return ShopifySampleData.formatGBP(totalSalesPence / orderCount)
    }
}

struct DashboardProduct: Identifiable {
    let id: String
    let name: String
    let price: String
    let inventory: Int
    let status: String
}

enum DashboardData {
    static let products: [DashboardProduct] = [
        DashboardProduct(id: "NK-001", name: "Starter Kit", price: "£45.00", inventory: 128, status: "Active"),
        DashboardProduct(id: "NK-002", name: "Pro Bundle", price: "£72.00", inventory: 64, status: "Active"),
        DashboardProduct(id: "NK-003", name: "Refill Pack", price: "£38.00", inventory: 210, status: "Active"),
        DashboardProduct(id: "NK-004", name: "Limited Edition Kit", price: "£79.99", inventory: 12, status: "Active"),
        DashboardProduct(id: "NK-005", name: "Gift Set", price: "£56.50", inventory: 45, status: "Active"),
    ]

    static func recentOrders(counter: Int, limit: Int = 24) -> [DashboardOrder] {
        let history = NotificationHistoryStore.load()
        if !history.isEmpty {
            return Array(history.prefix(limit))
        }
        let highest = max(1, counter)
        let lowest = max(1, highest - limit + 1)
        return (lowest...highest).reversed().map { makeOrder(counter: $0) }
    }

    static func todayStats(counter: Int) -> DashboardStats {
        let all = recentOrders(counter: counter, limit: 12)
        var orders = all.filter { Calendar.current.isDateInToday($0.placedAt) }
        if orders.isEmpty {
            orders = Array(all.prefix(6))
        }
        let sales = orders.reduce(0) { $0 + $1.totalPence }
        let sessions = max(orders.count * 18 + 42, 64)
        let conversion = orders.isEmpty ? 2.4 : min(6.8, Double(orders.count) / Double(sessions) * 100 + 1.8)
        return DashboardStats(
            totalSalesPence: sales,
            orderCount: orders.count,
            sessions: sessions,
            conversionRate: conversion
        )
    }

    static func makeOrder(counter: Int) -> DashboardOrder {
        let sample = ShopifySampleData.seededOrder(counter: counter)
        return DashboardOrder(
            id: counter,
            orderNumber: ShopifySampleData.orderNumber(counter: counter),
            total: sample.totalGBP,
            totalPence: sample.totalPence,
            itemsPhrase: sample.itemsPhrase,
            source: "Online Store",
            store: ShopifySampleData.defaultStore,
            customer: ShopifySampleData.customerName(counter: counter),
            placedAt: placedAt(counter: counter),
            status: "Paid",
            fulfillment: counter % 5 == 0 ? "Unfulfilled" : "Fulfilled"
        )
    }

    private static func placedAt(counter: Int) -> Date {
        let offsets = [3, 8, 14, 22, 35, 48, 67, 95, 128, 180, 360, 720]
        let minutes = offsets[abs(counter) % offsets.count]
        return Date().addingTimeInterval(-Double(minutes * 60))
    }

    static func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if Calendar.current.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: date))"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Shopify orders list timestamp: "Today at 2:41 PM"
    static func orderListTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if Calendar.current.isDateInToday(date) {
            return "Today at \(formatter.string(from: date))"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday at \(formatter.string(from: date))"
        }
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    static func notificationTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 3600 { return "\(max(1, seconds / 60))m" }
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return relativeTime(date)
    }

    static func isRecent(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < 86_400
    }

    static func salesChartPoints(counter: Int) -> [CGFloat] {
        let orders = recentOrders(counter: counter, limit: 16).reversed()
        guard !orders.isEmpty else {
            return [0.08, 0.15, 0.12, 0.22, 0.18, 0.35, 0.28, 0.48, 0.42, 0.62, 0.55, 0.78, 0.72, 0.88, 0.95, 1.0]
        }
        var cumulative: CGFloat = 0
        return orders.map { order in
            cumulative += CGFloat(order.totalPence)
            return cumulative
        }
    }

    static func salesChangeLabel(counter: Int) -> String {
        let pct = 8 + (counter % 14)
        return "↑ \(pct)% from yesterday"
    }

    static func sparkline(seed: Int, counter: Int) -> [CGFloat] {
        (0..<10).map { index in
            let value = abs((seed &* 13 &+ counter &* 7 &+ index &* 11) % 100)
            return CGFloat(0.15 + Double(value) / 100.0)
        }
    }
}

enum NotificationTemplate {
    static let variableHelp = """
    UK Shopify format:
    {order} — Order #1143, #1144…
    {total} — £45.00, £92.64… (based on items × £30–£80)
    {items_phrase} — 1 item, 2 items, 3 items…
    {source} — Online Store
    {store} — Novus Kits (on its own line)
    """

    static let insertable: [(label: String, token: String)] = [
        ("Order #", "{order}"),
        ("Total", "{total}"),
        ("Items", "{items_phrase}"),
        ("Source", "{source}"),
        ("Store", "{store}")
    ]

    private static let dynamicMarkers = [
        "{counter}", "{count}", "{index}", "{random",
        "{time}", "{date}", "{order", "{store}", "{items_phrase}",
        "{item_count}", "{source}", "{total", "{amount"
    ]

    static func isDynamic(_ text: String) -> Bool {
        dynamicMarkers.contains { text.contains($0) }
    }

    static func render(_ template: String, counter: Int, fireDate: Date) -> String {
        guard !template.isEmpty else { return template }

        let needsOrder = template.contains("{total")
            || template.contains("{amount")
            || template.contains("{items_phrase}")
            || template.contains("{item_count}")
        let sampleOrder = needsOrder ? ShopifySampleData.randomOrder() : nil

        var result = template
        result = result.replacingOccurrences(of: "{counter}", with: "\(counter)")
        result = result.replacingOccurrences(of: "{count}", with: "\(counter)")
        result = result.replacingOccurrences(of: "{index}", with: "\(counter)")

        result = replaceToken("{order}", in: result) { _ in
            ShopifySampleData.orderNumber(counter: counter)
        }
        result = replaceToken("{order_number}", in: result) { _ in
            ShopifySampleData.orderNumber(counter: counter)
        }
        result = replaceToken("{store}", in: result) { _ in
            ShopifySampleData.randomStore()
        }
        if let sampleOrder {
            result = replaceToken("{items_phrase}", in: result) { _ in
                sampleOrder.itemsPhrase
            }
            result = replaceToken("{item_count}", in: result) { _ in
                "\(sampleOrder.itemCount)"
            }
        }
        result = replaceToken("{source}", in: result) { _ in
            ShopifySampleData.randomSource()
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: fireDate))

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: fireDate))

        result = replaceTotalTokens(in: result, sampleOrder: sampleOrder)
        result = replaceRandomTokens(in: result)
        return result
    }

    private static func replaceToken(
        _ token: String,
        in text: String,
        value: (Range<String.Index>) -> String
    ) -> String {
        var result = text
        while let range = result.range(of: token) {
            result.replaceSubrange(range, with: value(range))
        }
        return result
    }

    private static func replaceTotalTokens(in text: String, sampleOrder: SampleOrder?) -> String {
        let pattern = #"\{(?:total|amount)(?::(\d+)-(\d+))?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let low = match.range(at: 1).location != NSNotFound
                ? (text as NSString).substring(with: match.range(at: 1))
                : "30"
            let high = match.range(at: 2).location != NSNotFound
                ? (text as NSString).substring(with: match.range(at: 2))
                : "80"
            let minValue = Int(low) ?? 30
            let maxValue = max(minValue, Int(high) ?? 80)
            let value: String
            if let sampleOrder {
                value = sampleOrder.totalGBP
            } else {
                value = ShopifySampleData.randomOrder(
                    perItemMinPounds: minValue,
                    perItemMaxPounds: maxValue
                ).totalGBP
            }
            result.replaceSubrange(range, with: value)
        }
        return result
    }

    private static func replaceRandomTokens(in text: String) -> String {
        let pattern = #"\{random(?::(\d+)-(\d+))?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let low = match.range(at: 1).location != NSNotFound
                ? (text as NSString).substring(with: match.range(at: 1))
                : "1"
            let high = match.range(at: 2).location != NSNotFound
                ? (text as NSString).substring(with: match.range(at: 2))
                : "100"
            let minValue = Int(low) ?? 1
            let maxValue = max(minValue, Int(high) ?? 100)
            let value = Int.random(in: minValue...maxValue)
            result.replaceSubrange(range, with: "\(value)")
        }
        return result
    }
}

enum CounterStore {
    private static func key(_ id: UUID) -> String { "counter.\(id.uuidString)" }

    static func current(_ id: UUID) -> Int {
        UserDefaults.standard.integer(forKey: key(id))
    }

    static func set(_ id: UUID, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key(id))
    }

    static func bump(_ id: UUID, to counter: Int) {
        set(id, max(current(id), counter))
    }

    static func reset(_ id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id))
    }
}

enum NotificationPayload {
    static let reminderID = "reminderID"
    static let counter = "counter"
    static let orderNumber = "orderNumber"
}

enum ScheduleCursorStore {
    private static func key(_ id: UUID) -> String { "schedule.\(id.uuidString)" }

    /// Last order counter already queued in pending notifications.
    static func scheduledThrough(_ id: UUID) -> Int {
        UserDefaults.standard.integer(forKey: key(id))
    }

    static func setScheduledThrough(_ id: UUID, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key(id))
    }

    static func reset(_ id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id))
    }
}

enum NotificationHistoryStore {
    private static let key = "notification.history"
    private static let limit = 80

    static func record(reminderID: UUID, counter: Int) {
        var history = load()
        let order = DashboardData.makeOrder(counter: counter)
        history.removeAll { $0.id == counter }
        history.insert(order, at: 0)
        if history.count > limit {
            history = Array(history.prefix(limit))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [DashboardOrder] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DashboardOrder].self, from: data) else {
            return []
        }
        return decoded
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

extension DashboardOrder: Codable {
    enum CodingKeys: String, CodingKey {
        case id, orderNumber, total, totalPence, itemsPhrase, source, store, customer, placedAt, status, fulfillment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        orderNumber = try container.decode(String.self, forKey: .orderNumber)
        total = try container.decode(String.self, forKey: .total)
        totalPence = try container.decode(Int.self, forKey: .totalPence)
        itemsPhrase = try container.decode(String.self, forKey: .itemsPhrase)
        source = try container.decode(String.self, forKey: .source)
        store = try container.decode(String.self, forKey: .store)
        customer = try container.decodeIfPresent(String.self, forKey: .customer) ?? ""
        placedAt = try container.decode(Date.self, forKey: .placedAt)
        status = try container.decode(String.self, forKey: .status)
        fulfillment = try container.decode(String.self, forKey: .fulfillment)
    }
}

// MARK: - Sound choices (filenames must match files bundled in the app)

struct SoundOption: Identifiable, Hashable {
    var id: String { fileName }
    let fileName: String   // "" == default
    let label: String
}

let bundledSounds: [SoundOption] = [
    SoundOption(fileName: "",          label: "Default"),
    SoundOption(fileName: "chime.wav", label: "Chime"),
    SoundOption(fileName: "ding.wav",  label: "Ding"),
    SoundOption(fileName: "bell.wav",  label: "Bell"),
    SoundOption(fileName: "alarm.wav", label: "Alarm")
]

enum SoundStore {
    private static let listKey = "customSounds.v1"
    private static let allowedExtensions = ["wav", "aiff", "aif", "caf", "m4a", "mp3"]

    static var soundsDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let folder = library.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static var customFileNames: [String] {
        get { UserDefaults.standard.stringArray(forKey: listKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: listKey) }
    }

    static func allOptions() -> [SoundOption] {
        let custom = customFileNames.map { name in
            SoundOption(fileName: name, label: name)
        }
        return bundledSounds + custom
    }

    @discardableResult
    static func importSound(from source: URL) throws -> String {
        let ext = source.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else {
            throw SoundImportError.unsupportedType
        }

        let base = source.deletingPathExtension().lastPathComponent
        let safeBase = base.isEmpty ? "custom" : String(base.prefix(40))
        var fileName = "\(safeBase).\(ext)"
        var destination = soundsDirectory.appendingPathComponent(fileName)
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            fileName = "\(safeBase)-\(counter).\(ext)"
            destination = soundsDirectory.appendingPathComponent(fileName)
            counter += 1
        }

        if source.startAccessingSecurityScopedResource() {
            defer { source.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            try FileManager.default.copyItem(at: source, to: destination)
        }

        if !customFileNames.contains(fileName) {
            customFileNames.append(fileName)
        }
        return fileName
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: soundsDirectory.appendingPathComponent(fileName))
        customFileNames.removeAll { $0 == fileName }
    }
}

enum SoundImportError: LocalizedError {
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Use a .wav, .aiff, .caf, .m4a, or .mp3 file under 30 seconds."
        }
    }
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    @Published var reminders: [Reminder] = []

    private let key = "shopify.merchant.reminders.v1"
    private let shopifySeedKey = "shopify.merchant.seeded.v1"

    init() {
        load()
        upgradeShopifyTemplates()
        seedShopifySampleIfNeeded()
    }

    private func upgradeShopifyTemplates() {
        var changed = false
        for index in reminders.indices {
            let old = reminders[index]
            let isShopifyStyle = old.title.contains("{order")
                || old.body.contains("{store}")
                || old.body.contains("{items_phrase}")
            let isOldFormat = old.body.contains("has a new order for")
                || (old.title.isEmpty && old.body.contains("totaling"))
                || old.body.contains("Facebook")
                || old.body.contains("·")
                || !old.burstEnabled
                || (isShopifyStyle && old.burstMinMilliseconds > 0)
            guard isShopifyStyle && isOldFormat else { continue }

            var updated = Reminder.shopifyOrder
            updated.id = old.id
            updated.isOn = old.isOn
            updated.soundName = old.soundName
            reminders[index] = updated
            changed = true
        }
        if changed {
            save()
            reschedule()
        }
    }

    private func seedShopifySampleIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: shopifySeedKey) else { return }
        UserDefaults.standard.set(true, forKey: shopifySeedKey)

        if reminders.isEmpty {
            reminders.insert(Reminder.shopifyOrder, at: 0)
            save()
            reschedule()
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data) else { return }
        reminders = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func upsert(_ reminder: Reminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.append(reminder)
        }
        save()
        Task {
            if reminder.isOn {
                await NotificationManager.shared.rebuild(reminder)
            } else {
                await NotificationManager.shared.reschedule(reminders)
            }
        }
    }

    func delete(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
        CounterStore.reset(reminder.id)
        ScheduleCursorStore.reset(reminder.id)
        save()
        reschedule()
    }

    func setOn(_ reminder: Reminder, _ on: Bool) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index].isOn = on
        save()
        reschedule()
    }

    private func reschedule() {
        let snapshot = reminders
        Task { await NotificationManager.shared.reschedule(snapshot) }
    }
}

// MARK: - Notification timing

enum NotificationTiming {
    static func randomSpacing(minSeconds: Int, maxSeconds: Int) -> TimeInterval {
        let lo = max(1, min(minSeconds, maxSeconds))
        let hi = max(lo, max(minSeconds, maxSeconds))
        return Double.random(in: Double(lo)...Double(hi))
    }

    static func burstStepMilliseconds(minMs: Int, maxMs: Int) -> Int {
        let lo = max(0, min(minMs, maxMs))
        let hi = max(lo, max(minMs, maxMs))
        if hi == 0 { return 0 }
        return Int.random(in: lo...hi)
    }

    /// Converts burst gap in ms to schedule offset. Instant (0ms) uses a tiny stagger so each ding is visible.
    static func burstScheduleOffset(stepMs: Int) -> TimeInterval {
        if stepMs > 0 { return Double(stepMs) / 1000 }
        return 0.05
    }

    static func burstStep(minSeconds: Double, maxSeconds: Double) -> TimeInterval {
        burstScheduleOffset(
            stepMs: burstStepMilliseconds(
                minMs: Int((minSeconds * 1000).rounded()),
                maxMs: Int((maxSeconds * 1000).rounded())
            )
        )
    }

    static func nextBurstOffset(averageSeconds: TimeInterval) -> TimeInterval {
        max(60, averageSeconds) * Double.random(in: 0.65...1.35)
    }
}

// MARK: - Notifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let foreground = ForegroundDelegate()

    private init() {
        center.delegate = foreground
    }

    @discardableResult
    func requestAuth() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private let maxPending = 64

    func reschedule(_ reminders: [Reminder]) async {
        let pending = await center.pendingNotificationRequests()
        let active = reminders.filter(\.isOn)

        guard !active.isEmpty else {
            center.removeAllPendingNotificationRequests()
            return
        }

        let activeIDs = Set(active.map(\.id))
        let staleIDs = pending.compactMap { request -> String? in
            guard let reminderID = Self.reminderID(from: request.identifier, activeIDs: activeIDs) else {
                return request.identifier
            }
            return activeIDs.contains(reminderID) ? nil : request.identifier
        }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let remaining = pending.filter { !staleIDs.contains($0.identifier) }
        let staticReminders = active.filter { !$0.usesDynamicText && $0.intervalSeconds >= 60 }
        let sequenced = active.filter { $0.usesDynamicText || $0.intervalSeconds < 60 }
        let sequenceSlots = max(0, maxPending - remaining.count)

        for reminder in staticReminders where !remaining.contains(where: { $0.identifier == reminder.id.uuidString }) {
            await scheduleRepeating(reminder)
        }

        guard sequenceSlots > 0, !sequenced.isEmpty else { return }

        let perReminder = max(1, sequenceSlots / sequenced.count)
        for reminder in sequenced {
            await topUpSequence(reminder, count: perReminder, existing: remaining)
        }
    }

    /// Rebuild all pending notifications for one reminder (after settings change).
    func rebuild(_ reminder: Reminder) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .filter { Self.matches(reminderID: reminder.id, identifier: $0.identifier) }
            .map(\.identifier)
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        ScheduleCursorStore.setScheduledThrough(reminder.id, CounterStore.current(reminder.id))
        await scheduleSequence(
            reminder,
            count: maxPending,
            startingCounter: CounterStore.current(reminder.id)
        )
    }

    private func topUpSequence(_ reminder: Reminder, count: Int, existing: [UNNotificationRequest]) async {
        let existingForReminder = existing.filter { Self.matches(reminderID: reminder.id, identifier: $0.identifier) }
        guard existingForReminder.count < maxPending else { return }

        let slots = min(count, maxPending - existingForReminder.count)
        guard slots > 0 else { return }

        let highestScheduled = existingForReminder
            .compactMap { Self.counter(from: $0) }
            .max() ?? ScheduleCursorStore.scheduledThrough(reminder.id)
        let startCounter = max(CounterStore.current(reminder.id), highestScheduled)

        await scheduleSequence(
            reminder,
            count: slots,
            startingCounter: startCounter
        )
    }

    private func scheduleRepeating(_ reminder: Reminder) async {
        let content = makeContent(
            for: reminder,
            fallbackTitle: "Order",
            counter: CounterStore.current(reminder.id) + 1,
            fireDate: Date().addingTimeInterval(reminder.intervalSeconds)
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Schedules separate alerts so each one can have its own counter/random text.
    private func scheduleSequence(
        _ reminder: Reminder,
        count: Int,
        startingCounter: Int
    ) async {
        let interval = max(1, reminder.intervalSeconds)
        var cumulative: TimeInterval = 0
        var scheduled = 0
        var untilBurst = reminder.burstEnabled
            ? NotificationTiming.nextBurstOffset(averageSeconds: reminder.burstEverySeconds)
            : .infinity
        var lastCounter = startingCounter

        while scheduled < count {
            let canBurst = reminder.burstEnabled
                && scheduled + reminder.burstCount <= count
                && cumulative >= untilBurst

            if canBurst {
                let (lo, hi) = reminder.normalizedBurstMilliseconds
                for burstIndex in 0..<reminder.burstCount {
                    if burstIndex > 0 {
                        let stepMs = NotificationTiming.burstStepMilliseconds(minMs: lo, maxMs: hi)
                        cumulative += NotificationTiming.burstScheduleOffset(stepMs: stepMs)
                    }
                    scheduled += 1
                    lastCounter = startingCounter + scheduled
                    await enqueueSequenceAlert(
                        reminder: reminder,
                        slot: lastCounter,
                        counter: lastCounter,
                        cumulative: cumulative
                    )
                }
                untilBurst = cumulative + NotificationTiming.nextBurstOffset(
                    averageSeconds: reminder.burstEverySeconds
                )
                continue
            }

            let step: TimeInterval
            if reminder.usesDynamicText {
                let (lo, hi) = reminder.normalizedSpacingSeconds
                step = NotificationTiming.randomSpacing(minSeconds: lo, maxSeconds: hi)
            } else {
                step = interval
            }
            cumulative += step
            scheduled += 1
            lastCounter = startingCounter + scheduled
            await enqueueSequenceAlert(
                reminder: reminder,
                slot: lastCounter,
                counter: lastCounter,
                cumulative: cumulative
            )

            if reminder.burstEnabled {
                untilBurst -= step
            }
        }

        ScheduleCursorStore.setScheduledThrough(reminder.id, lastCounter)
    }

    private func enqueueSequenceAlert(
        reminder: Reminder,
        slot: Int,
        counter: Int,
        cumulative: TimeInterval
    ) async {
        let fireDate = Date().addingTimeInterval(cumulative)
        let content = makeContent(
            for: reminder,
            fallbackTitle: "Order",
            counter: counter,
            fireDate: fireDate
        )
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(0.05, cumulative),
            repeats: false
        )
        let identifier = "\(reminder.id.uuidString)-\(counter)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func handleDelivery(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        guard
            let idString = userInfo[NotificationPayload.reminderID] as? String,
            let reminderID = UUID(uuidString: idString),
            let counter = userInfo[NotificationPayload.counter] as? Int
        else { return }

        CounterStore.bump(reminderID, to: counter)
        NotificationHistoryStore.record(reminderID: reminderID, counter: counter)
    }

    private static func matches(reminderID: UUID, identifier: String) -> Bool {
        identifier == reminderID.uuidString || identifier.hasPrefix(reminderID.uuidString + "-")
    }

    private static func reminderID(from identifier: String, activeIDs: Set<UUID>) -> UUID? {
        for id in activeIDs where matches(reminderID: id, identifier: identifier) {
            return id
        }
        return nil
    }

    private static func counter(from request: UNNotificationRequest) -> Int? {
        request.content.userInfo[NotificationPayload.counter] as? Int
    }

    /// Fires a burst starting ~2 seconds out — preview the rapid ding effect.
    func sendBurstTest(_ reminder: Reminder) async {
        let count = max(2, reminder.burstCount)
        let (lo, hi) = reminder.normalizedBurstMilliseconds
        var cumulative: TimeInterval = 2
        let baseCounter = CounterStore.current(reminder.id)

        for index in 1...count {
            if index > 1 {
                let stepMs = NotificationTiming.burstStepMilliseconds(minMs: lo, maxMs: hi)
                cumulative += NotificationTiming.burstScheduleOffset(stepMs: stepMs)
            }
            let counter = baseCounter + index
            let fireDate = Date().addingTimeInterval(cumulative)
            let content = makeContent(
                for: reminder,
                fallbackTitle: "Order",
                counter: counter,
                fireDate: fireDate
            )
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(0.05, cumulative),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "burst-test-\(index)-" + UUID().uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }

        CounterStore.set(reminder.id, baseCounter + count)
    }

    /// Fires once, ~2 seconds out, so you can preview a notification.
    func sendTest(_ reminder: Reminder) async {
        let counter = CounterStore.current(reminder.id) + 1
        let content = makeContent(
            for: reminder,
            fallbackTitle: "Test",
            counter: counter,
            fireDate: Date().addingTimeInterval(2)
        )
        if content.body.isEmpty { content.body = "This is a test" }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test-" + UUID().uuidString, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func makeContent(
        for reminder: Reminder,
        fallbackTitle: String,
        counter: Int,
        fireDate: Date
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let rawTitle = reminder.title.isEmpty ? fallbackTitle : reminder.title
        content.title = NotificationTemplate.render(rawTitle, counter: counter, fireDate: fireDate)
        content.body = NotificationTemplate.render(reminder.body, counter: counter, fireDate: fireDate)
        let orderNumber = ShopifySampleData.orderNumber(counter: counter)
        // Unique thread per order so iOS doesn't collapse notifications into one stack.
        content.threadIdentifier = "order-\(orderNumber)"
        content.summaryArgument = orderNumber
        content.summaryArgumentCount = 1
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            NotificationPayload.reminderID: reminder.id.uuidString,
            NotificationPayload.counter: counter,
            NotificationPayload.orderNumber: orderNumber
        ]
        content.sound = reminder.soundName.isEmpty
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(reminder.soundName))
        return content
    }
}

/// Lets notifications show (with sound) even while the app is open — handy for the test button.
final class ForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        NotificationManager.shared.handleDelivery(notification)
        return [.banner, .sound, .badge, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationManager.shared.handleDelivery(response.notification)
    }
}
