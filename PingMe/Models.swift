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

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var soundName: String = "chime.wav"   // "" == system default
    var every: Int = 1
    var unit: RepeatUnit = .hours
    var isOn: Bool = true

    var intervalSeconds: TimeInterval {
        Double(max(1, every)) * unit.seconds
    }

    var cadenceText: String {
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

    /// Matches real Shopify order notifications.
    static let shopifyOrder = Reminder(
        title: "",
        body: "{store} has a new order for {items_phrase} totaling {total} from {source}.",
        soundName: "ding.wav",
        every: 3,
        unit: .minutes,
        isOn: true
    )
}

// MARK: - Template variables

enum ShopifySampleData {
    static let stores = [
        "HoH Fashion", "HoH Fashion", "HoH Fashion",
        "Main Street Boutique", "Urban Threads", "Glow Skincare"
    ]

    static let sources = [
        "Online Store", "Online Store", "Online Store",
        "Facebook & Instagram", "TikTok Shop", "Shop app", "Google"
    ]

    static func randomStore() -> String {
        stores.randomElement() ?? "HoH Fashion"
    }

    static func randomSource() -> String {
        sources.randomElement() ?? "Online Store"
    }

    static func randomItemCountPhrase() -> String {
        let count = Int.random(in: 1...4)
        return count == 1 ? "1 item" : "\(count) items"
    }

    static func randomTotal(minDollars: Int = 8, maxDollars: Int = 250) -> String {
        let cents = Int.random(in: minDollars * 100...maxDollars * 100)
        let dollars = cents / 100
        let remainder = cents % 100
        return String(format: "$%d.%02d", dollars, remainder)
    }
}

enum NotificationTemplate {
    static let variableHelp = """
    Shopify style (like the real app):
    {store} — store name (default HoH Fashion)
    {items_phrase} — "1 item" or "2 items"
    {total} — price like $70.49
    {source} — Online Store, Facebook & Instagram, etc.
    """

    static let insertable: [(label: String, token: String)] = [
        ("Store", "{store}"),
        ("Items", "{items_phrase}"),
        ("Total", "{total}"),
        ("Source", "{source}"),
        ("Total range", "{total:10-80}"),
        ("Counter", "{counter}"),
        ("Random", "{random}")
    ]

    private static let dynamicMarkers = [
        "{counter}", "{count}", "{index}", "{random",
        "{time}", "{date}", "{store}", "{items_phrase}",
        "{item_count}", "{source}", "{total", "{amount"
    ]

    static func isDynamic(_ text: String) -> Bool {
        dynamicMarkers.contains { text.contains($0) }
    }

    static func render(_ template: String, counter: Int, fireDate: Date) -> String {
        guard !template.isEmpty else { return template }

        var result = template
        result = result.replacingOccurrences(of: "{counter}", with: "\(counter)")
        result = result.replacingOccurrences(of: "{count}", with: "\(counter)")
        result = result.replacingOccurrences(of: "{index}", with: "\(counter)")

        result = replaceToken("{store}", in: result) { _ in
            ShopifySampleData.randomStore()
        }
        result = replaceToken("{items_phrase}", in: result) { _ in
            ShopifySampleData.randomItemCountPhrase()
        }
        result = replaceToken("{item_count}", in: result) { _ in
            let count = Int.random(in: 1...4)
            return "\(count)"
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

        result = replaceTotalTokens(in: result)
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

    private static func replaceTotalTokens(in text: String) -> String {
        let pattern = #"\{(?:total|amount)(?::(\d+)-(\d+))?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let low = match.range(at: 1).location != NSNotFound
                ? (text as NSString).substring(with: match.range(at: 1))
                : "12"
            let high = match.range(at: 2).location != NSNotFound
                ? (text as NSString).substring(with: match.range(at: 2))
                : "349"
            let minValue = Int(low) ?? 12
            let maxValue = max(minValue, Int(high) ?? 349)
            let value = ShopifySampleData.randomTotal(minDollars: minValue, maxDollars: maxValue)
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

    static func reset(_ id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id))
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

    private let key = "reminders.v1"
    private let shopifySeedKey = "seeded.shopify.v2"

    init() {
        load()
        seedShopifySampleIfNeeded()
    }

    private func seedShopifySampleIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: shopifySeedKey) else { return }
        UserDefaults.standard.set(true, forKey: shopifySeedKey)

        if let idx = reminders.firstIndex(where: {
            $0.body.contains("{customer}") || $0.title.contains("#{order}")
        }) {
            var updated = Reminder.shopifyOrder
            updated.id = reminders[idx].id
            reminders[idx] = updated
        } else {
            reminders.insert(Reminder.shopifyOrder, at: 0)
        }
        save()
        reschedule()
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
        reschedule()
    }

    func delete(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
        CounterStore.reset(reminder.id)
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
        center.removeAllPendingNotificationRequests()

        let active = reminders.filter(\.isOn)
        guard !active.isEmpty else { return }

        let staticReminders = active.filter { !$0.usesDynamicText && $0.intervalSeconds >= 60 }
        let sequenced = active.filter { $0.usesDynamicText || $0.intervalSeconds < 60 }
        let sequenceSlots = max(0, maxPending - staticReminders.count)

        for reminder in staticReminders {
            await scheduleRepeating(reminder)
        }

        guard sequenceSlots > 0, !sequenced.isEmpty else { return }

        let perReminder = max(1, sequenceSlots / sequenced.count)
        for reminder in sequenced {
            await scheduleSequence(reminder, count: perReminder)
        }
    }

    private func scheduleRepeating(_ reminder: Reminder) async {
        let content = makeContent(
            for: reminder,
            fallbackTitle: "Reminder",
            counter: CounterStore.current(reminder.id) + 1,
            fireDate: Date().addingTimeInterval(reminder.intervalSeconds)
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Schedules separate alerts so each one can have its own counter/random text.
    private func scheduleSequence(_ reminder: Reminder, count: Int) async {
        let interval = max(1, reminder.intervalSeconds)
        let baseCounter = CounterStore.current(reminder.id)

        for index in 1...count {
            let counter = baseCounter + index
            let fireDate = Date().addingTimeInterval(interval * Double(index))
            let content = makeContent(
                for: reminder,
                fallbackTitle: "Reminder",
                counter: counter,
                fireDate: fireDate
            )
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval * Double(index), repeats: false)
            let identifier = "\(reminder.id.uuidString)-\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
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
        content.threadIdentifier = reminder.id.uuidString
        content.sound = reminder.soundName.isEmpty
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(reminder.soundName))
        return content
    }
}

/// Lets notifications show (with sound) even while the app is open — handy for the test button.
final class ForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
