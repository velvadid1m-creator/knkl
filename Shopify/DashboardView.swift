import SwiftUI

// MARK: - Shopify design tokens (Polaris mobile)

enum ShopifyTheme {
    static let brand = Color(red: 0, green: 0.502, blue: 0.376)           // #008060
    static let brandDark = Color(red: 0.004, green: 0.361, blue: 0.271)    // #015C43
    static let surface = Color(red: 0.965, green: 0.965, blue: 0.969)     // #F6F6F7
    static let surfaceSubdued = Color(red: 0.937, green: 0.941, blue: 0.949)
    static let card = Color.white
    static let text = Color(red: 0.125, green: 0.133, blue: 0.137)       // #202223
    static let subdued = Color(red: 0.427, green: 0.443, blue: 0.459)    // #6D7175
    static let border = Color(red: 0.882, green: 0.890, blue: 0.898)        // #E1E3E5
    static let success = Color(red: 0.075, green: 0.573, blue: 0.365)
    static let warning = Color(red: 0.737, green: 0.553, blue: 0)
    static let critical = Color(red: 0.796, green: 0.255, blue: 0.169)
}

enum ShopifyTabBar {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        appearance.shadowColor = UIColor(ShopifyTheme.border)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Root

struct DashboardShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: Store
    @State private var tab = 0
    @State private var showNotifications = false

    private var orderCounter: Int {
        guard let reminder = store.reminders.first else { return 9 }
        return max(1, CounterStore.current(reminder.id))
    }

    var body: some View {
        TabView(selection: $tab) {
            ShopifyHomeView(orderCounter: orderCounter, showNotifications: $showNotifications)
                .tabItem { Label("Home", systemImage: tab == 0 ? "house.fill" : "house") }
                .tag(0)

            ShopifyOrdersView(orderCounter: orderCounter)
                .tabItem { Label("Orders", systemImage: tab == 1 ? "list.clipboard.fill" : "list.clipboard") }
                .tag(1)

            ShopifyProductsView()
                .tabItem { Label("Products", systemImage: tab == 2 ? "tag.fill" : "tag") }
                .tag(2)

            ShopifyMenuView()
                .tabItem { Label("Menu", systemImage: "line.3.horizontal") }
                .tag(3)
        }
        .tint(ShopifyTheme.brand)
        .onAppear { ShopifyTabBar.configure() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await NotificationManager.shared.reschedule(store.reminders) }
        }
        .sheet(isPresented: $showNotifications) {
            ShopifyNotificationsView(orderCounter: orderCounter)
        }
    }
}

// MARK: - Shared components

/// Shopify shopping-bag mark (drawn — matches merchant app icon shape).
private struct ShopifyBagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.24, y: h * 0.36))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.76, y: h * 0.36),
            control: CGPoint(x: w * 0.5, y: h * 0.08)
        )
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.88))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.88),
            control: CGPoint(x: w * 0.5, y: h * 1.02)
        )
        path.closeSubpath()
        return path
    }
}

private struct ShopifyBagMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(ShopifyTheme.brandDark)
                .frame(width: size, height: size)
            ShopifyBagShape()
                .fill(.white)
                .frame(width: size * 0.52, height: size * 0.52)
        }
    }
}

private extension View {
    func shopifyCardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

private struct ShopifyStoreBar: View {
    var showsSearch = false
    @Binding var showNotifications: Bool

    var body: some View {
        HStack(spacing: 12) {
            ShopifyBagMark(size: 34)
            Button {} label: {
                HStack(spacing: 4) {
                    Text(ShopifySampleData.defaultStore)
                        .font(.headline)
                        .foregroundStyle(ShopifyTheme.text)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ShopifyTheme.subdued)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if showsSearch {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(ShopifyTheme.text)
            }
            Image(systemName: "message")
                .font(.body.weight(.medium))
                .foregroundStyle(ShopifyTheme.text)
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.body.weight(.medium))
                        .foregroundStyle(ShopifyTheme.text)
                    Circle()
                        .fill(ShopifyTheme.critical)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ShopifyTheme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ShopifyTheme.border).frame(height: 1)
        }
    }
}

private struct DateRangePill: View {
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.subheadline.weight(.semibold))
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(ShopifyTheme.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ShopifyTheme.surfaceSubdued, in: Capsule())
    }
}

private struct DeltaBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(ShopifyTheme.success)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ShopifyTheme.success.opacity(0.12), in: Capsule())
    }
}

private struct Sparkline: View {
    let points: [CGFloat]
    var color: Color = ShopifyTheme.brand

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxY = max(points.max() ?? 1, 0.01)
            let step = w / CGFloat(max(points.count - 1, 1))

            Path { path in
                guard points.count > 1 else { return }
                path.move(to: CGPoint(x: 0, y: h - (points[0] / maxY) * h))
                for index in 1..<points.count {
                    path.addLine(to: CGPoint(
                        x: CGFloat(index) * step,
                        y: h - (points[index] / maxY) * h
                    ))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 28)
    }
}

private struct SalesChart: View {
    let points: [CGFloat]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxY = max(points.max() ?? 1, 0.01)
            let step = w / CGFloat(max(points.count - 1, 1))

            ZStack {
                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: 0, y: h - (points[0] / maxY) * h * 0.85))
                    for index in 1..<points.count {
                        let x = CGFloat(index) * step
                        let y = h - (points[index] / maxY) * h * 0.85
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(ShopifyTheme.brand, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h - (points[0] / maxY) * h * 0.85))
                    for index in 1..<points.count {
                        let x = CGFloat(index) * step
                        let y = h - (points[index] / maxY) * h * 0.85
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: CGFloat(points.count - 1) * step, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [ShopifyTheme.brand.opacity(0.28), ShopifyTheme.brand.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 120)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let delta: String
    let sparkline: [CGFloat]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ShopifyTheme.subdued)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ShopifyTheme.text)
                Text(delta)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ShopifyTheme.success)
            }
            Sparkline(points: sparkline)
        }
        .frame(width: 132, alignment: .leading)
        .padding(14)
        .background(ShopifyTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shopifyCardShadow()
    }
}

private struct ShopifyCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(ShopifyTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shopifyCardShadow()
    }
}

/// Push notification replica row (exact lock-screen format).
private struct ShopifyNotificationRow: View {
    let order: DashboardOrder

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ShopifyBagMark(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(order.notificationTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ShopifyTheme.text)
                    Spacer(minLength: 8)
                    Text(DashboardData.notificationTime(order.placedAt))
                        .font(.caption)
                        .foregroundStyle(ShopifyTheme.subdued)
                }
                Text(order.subtitleLine)
                    .font(.subheadline)
                    .foregroundStyle(ShopifyTheme.subdued)
                    .fixedSize(horizontal: false, vertical: true)
                Text(order.store)
                    .font(.subheadline)
                    .foregroundStyle(ShopifyTheme.text)
            }
        }
        .padding(.vertical, 8)
    }
}

/// Home + orders list — real Shopify merchant app row.
private struct ShopifyOrderListCell: View {
    let order: DashboardOrder

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text("#\(order.orderNumber)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ShopifyTheme.text)
                    Spacer(minLength: 8)
                    Text(DashboardData.orderListTime(order.placedAt))
                        .font(.caption)
                        .foregroundStyle(ShopifyTheme.subdued)
                }
                if !order.customer.isEmpty {
                    Text(order.customer)
                        .font(.subheadline)
                        .foregroundStyle(ShopifyTheme.subdued)
                }
                Text(order.total)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ShopifyTheme.text)
                HStack(spacing: 6) {
                    FulfillmentBadge(text: order.status, tone: .paid)
                    if order.fulfillment == "Unfulfilled" {
                        FulfillmentBadge(text: "Unfulfilled", tone: .warning)
                    } else {
                        FulfillmentBadge(text: "Fulfilled", tone: .neutral)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct FulfillmentBadge: View {
    enum Tone { case paid, warning, neutral }

    let text: String
    let tone: Tone

    private var color: Color {
        switch tone {
        case .paid: return ShopifyTheme.success
        case .warning: return ShopifyTheme.warning
        case .neutral: return ShopifyTheme.subdued
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if tone == .paid {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }
}

private struct ShopifySearchBar: View {
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ShopifyTheme.subdued)
            Text(placeholder)
                .font(.subheadline)
                .foregroundStyle(ShopifyTheme.subdued)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ShopifyTheme.surfaceSubdued, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Home (Shopify admin home)

struct ShopifyHomeView: View {
    let orderCounter: Int
    @Binding var showNotifications: Bool

    private var orders: [DashboardOrder] {
        DashboardData.recentOrders(counter: orderCounter, limit: 12)
    }

    private var stats: DashboardStats {
        DashboardData.todayStats(counter: orderCounter)
    }

    private var chartPoints: [CGFloat] {
        DashboardData.salesChartPoints(counter: orderCounter)
    }

    private var salesDelta: String {
        DashboardData.salesChangeLabel(counter: orderCounter)
    }

    private var unfulfilledCount: Int {
        orders.filter { $0.fulfillment == "Unfulfilled" }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ShopifyStoreBar(showNotifications: $showNotifications)

                    VStack(alignment: .leading, spacing: 16) {
                        ShopifyCard {
                            VStack(alignment: .leading, spacing: 14) {
                                DateRangePill(label: "Today")

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Total sales")
                                        .font(.subheadline)
                                        .foregroundStyle(ShopifyTheme.subdued)
                                    Text(stats.totalSales)
                                        .font(.system(size: 36, weight: .semibold))
                                        .foregroundStyle(ShopifyTheme.text)
                                    DeltaBadge(text: salesDelta)
                                }

                                SalesChart(points: chartPoints)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                MetricTile(
                                    title: "Sessions",
                                    value: "\(stats.sessions)",
                                    delta: "↑ \(6 + orderCounter % 5)%",
                                    sparkline: DashboardData.sparkline(seed: 1, counter: orderCounter)
                                )
                                MetricTile(
                                    title: "Orders",
                                    value: "\(stats.orderCount)",
                                    delta: "↑ \(4 + orderCounter % 7)%",
                                    sparkline: DashboardData.sparkline(seed: 2, counter: orderCounter)
                                )
                                MetricTile(
                                    title: "Conversion rate",
                                    value: String(format: "%.1f%%", stats.conversionRate),
                                    delta: "↑ \(2 + orderCounter % 3)%",
                                    sparkline: DashboardData.sparkline(seed: 3, counter: orderCounter)
                                )
                                MetricTile(
                                    title: "Average order value",
                                    value: stats.averageOrder,
                                    delta: "↑ \(3 + orderCounter % 4)%",
                                    sparkline: DashboardData.sparkline(seed: 4, counter: orderCounter)
                                )
                            }
                        }

                        if unfulfilledCount > 0 {
                            ShopifyCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(unfulfilledCount) orders to fulfill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(ShopifyTheme.text)
                                        Text("Review and ship open orders")
                                            .font(.caption)
                                            .foregroundStyle(ShopifyTheme.subdued)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(ShopifyTheme.subdued)
                                }
                            }
                        }

                        ShopifyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sales by channel")
                                    .font(.headline)
                                    .foregroundStyle(ShopifyTheme.text)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Online Store")
                                            .font(.subheadline.weight(.medium))
                                        Text(stats.totalSales)
                                            .font(.title3.weight(.semibold))
                                    }
                                    Spacer()
                                    Text("\(stats.orderCount) orders")
                                        .font(.caption)
                                        .foregroundStyle(ShopifyTheme.subdued)
                                }

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(ShopifyTheme.brand)
                                        .frame(width: geo.size.width * 0.92, height: 8)
                                }
                                .frame(height: 8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Recent orders")
                                    .font(.headline)
                                Spacer()
                                Button { showNotifications = true } label: {
                                    Text("View all")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(ShopifyTheme.brand)
                                }
                            }

                            ShopifyCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(orders.prefix(5))) { order in
                                        NavigationLink(value: order) {
                                            ShopifyOrderListCell(order: order)
                                        }
                                        .buttonStyle(.plain)
                                        if order.id != orders.prefix(5).last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .background(ShopifyTheme.surface)
            .navigationBarHidden(true)
            .navigationDestination(for: DashboardOrder.self) { order in
                ShopifyOrderDetailView(order: order)
            }
        }
    }
}

// MARK: - Orders

struct ShopifyOrdersView: View {
    let orderCounter: Int
    @State private var filter = "Open"

    private let filters = ["Open", "Archived", "All"]

    private var orders: [DashboardOrder] {
        let all = DashboardData.recentOrders(counter: orderCounter, limit: 40)
        switch filter {
        case "Open": return all.filter { $0.fulfillment == "Unfulfilled" || DashboardData.isRecent($0.placedAt) }
        case "Archived": return all.filter { $0.fulfillment == "Fulfilled" && !DashboardData.isRecent($0.placedAt) }
        default: return all
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Orders")
                            .font(.largeTitle.bold())
                            .foregroundStyle(ShopifyTheme.text)
                        Spacer()
                        Button {} label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ShopifyTheme.brand)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ShopifySearchBar(placeholder: "Search orders")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { item in
                                Button { filter = item } label: {
                                    Text(item)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(filter == item ? ShopifyTheme.text : ShopifyTheme.subdued)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            filter == item ? ShopifyTheme.card : ShopifyTheme.surfaceSubdued,
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule().stroke(ShopifyTheme.border, lineWidth: filter == item ? 1 : 0)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)
                .background(ShopifyTheme.card)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ShopifyTheme.border).frame(height: 1)
                }

                List {
                    ForEach(orders) { order in
                        NavigationLink(value: order) {
                            ShopifyOrderListCell(order: order)
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .listRowSeparator(.visible)
                        .listRowBackground(ShopifyTheme.card)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(ShopifyTheme.surface)
            .navigationDestination(for: DashboardOrder.self) { order in
                ShopifyOrderDetailView(order: order)
            }
        }
    }
}

// MARK: - Notifications (exact push replica)

struct ShopifyNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    let orderCounter: Int

    private var orders: [DashboardOrder] {
        DashboardData.recentOrders(counter: orderCounter, limit: 30)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orders) { order in
                        ShopifyNotificationRow(order: order)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    Text("Today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ShopifyTheme.subdued)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Order detail (full-screen replica)

struct ShopifyOrderDetailView: View {
    let order: DashboardOrder

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("#\(order.orderNumber)")
                        .font(.largeTitle.bold())
                    Text(DashboardData.orderListTime(order.placedAt))
                        .font(.subheadline)
                        .foregroundStyle(ShopifyTheme.subdued)
                    HStack(spacing: 8) {
                        FulfillmentBadge(text: order.status, tone: .paid)
                        FulfillmentBadge(
                            text: order.fulfillment,
                            tone: order.fulfillment == "Unfulfilled" ? .warning : .neutral
                        )
                    }
                }
                .padding(.horizontal, 16)

                detailCard(title: "Timeline") {
                    timelineRow("Order placed", DashboardData.orderListTime(order.placedAt), done: true)
                    timelineRow("Payment received", order.status, done: true)
                    timelineRow("Fulfillment", order.fulfillment, done: order.fulfillment == "Fulfilled")
                }

                detailCard(title: "Customer") {
                    if order.customer.isEmpty {
                        Text("No customer")
                            .foregroundStyle(ShopifyTheme.subdued)
                    } else {
                        Text(order.customer)
                            .font(.headline)
                    }
                    HStack(spacing: 16) {
                        Image(systemName: "envelope")
                        Image(systemName: "phone")
                        Image(systemName: "message")
                    }
                    .font(.body)
                    .foregroundStyle(ShopifyTheme.brand)
                    .padding(.top, 4)
                }

                detailCard(title: "Payment") {
                    row("Subtotal", order.total)
                    row("Shipping", "£0.00")
                    row("Taxes", "£0.00")
                    Divider().padding(.vertical, 4)
                    row("Total", order.total, bold: true)
                    row("Paid", order.total, bold: false)
                }

                detailCard(title: "Fulfillment") {
                    row("Status", order.fulfillment)
                    row("Channel", order.source)
                    row("Items", order.itemsPhrase)
                }

                detailCard(title: "Notes") {
                    Text("No notes from customer")
                        .font(.subheadline)
                        .foregroundStyle(ShopifyTheme.subdued)
                }
            }
            .padding(.vertical, 16)
        }
        .background(ShopifyTheme.surface)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ShopifyTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shopifyCardShadow()
        .padding(.horizontal, 16)
    }

    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(ShopifyTheme.subdued)
            Spacer()
            Text(value)
                .fontWeight(bold ? .semibold : .regular)
        }
        .font(.subheadline)
    }

    private func timelineRow(_ title: String, _ detail: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(done ? ShopifyTheme.brand : ShopifyTheme.border)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ShopifyTheme.subdued)
            }
        }
    }
}

// MARK: - Products

struct ShopifyProductsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Products")
                            .font(.largeTitle.bold())
                        Spacer()
                        Button {} label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundStyle(ShopifyTheme.text)
                        }
                        Button {} label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ShopifyTheme.brand)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    ShopifySearchBar(placeholder: "Search products")
                }
                .padding(.bottom, 8)
                .background(ShopifyTheme.card)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ShopifyTheme.border).frame(height: 1)
                }

                List {
                    Section {
                        ForEach(DashboardData.products) { product in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(ShopifyTheme.surfaceSubdued)
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(ShopifyTheme.subdued)
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ShopifyTheme.text)
                                    Text("\(product.inventory) in stock for 1 variant")
                                        .font(.caption)
                                        .foregroundStyle(ShopifyTheme.subdued)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(product.price)
                                        .font(.subheadline.weight(.medium))
                                    FulfillmentBadge(text: product.status, tone: .paid)
                                }
                            }
                            .listRowBackground(ShopifyTheme.card)
                        }
                    } header: {
                        Text("\(DashboardData.products.count) products")
                            .font(.subheadline)
                            .foregroundStyle(ShopifyTheme.subdued)
                            .textCase(nil)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(ShopifyTheme.surface)
        }
    }
}

// MARK: - Menu (real Shopify menu + hidden alert settings)

struct ShopifyMenuView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ShopifyBagMark(size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ShopifySampleData.defaultStore)
                                .font(.headline)
                            Text("novuskits.myshopify.com")
                                .font(.caption)
                                .foregroundStyle(ShopifyTheme.subdued)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ShopifyTheme.subdued)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    menuRow("Orders", icon: "list.clipboard")
                    menuRow("Products", icon: "tag")
                    menuRow("Customers", icon: "person.2")
                    menuRow("Analytics", icon: "chart.line.uptrend.xyaxis")
                    menuRow("Marketing", icon: "megaphone")
                    menuRow("Discounts", icon: "percent")
                }

                Section("Sales channels") {
                    menuRow("Online Store", icon: "globe")
                    menuRow("Shop", icon: "bag")
                }

                Section("Apps") {
                    menuRow("Inbox", icon: "message")
                    menuRow("Sidekick", icon: "sparkles")
                }

                Section {
                    NavigationLink {
                        ShopifySettingsView()
                            .environmentObject(store)
                    } label: {
                        menuRow("Settings", icon: "gearshape", chevron: false)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Menu")
        }
    }

    private func menuRow(_ title: String, icon: String, chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(ShopifyTheme.brand)
            Text(title)
            if chevron { Spacer() }
        }
    }
}

struct ShopifySettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var showingAdd = false
    @State private var editing: Reminder?

    var body: some View {
        List {
            Section("Store") {
                LabeledContent("Name", value: ShopifySampleData.defaultStore)
                LabeledContent("Domain", value: "novuskits.myshopify.com")
            }

            Section("Notifications") {
                Text("Order push notifications")
                    .font(.subheadline)
                    .foregroundStyle(ShopifyTheme.subdued)
                ForEach(store.reminders) { reminder in
                    Button { editing = reminder } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Order alerts")
                                    .foregroundStyle(ShopifyTheme.text)
                                Text(reminder.isOn ? "On" : "Off")
                                    .font(.caption)
                                    .foregroundStyle(ShopifyTheme.subdued)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ShopifyTheme.subdued)
                        }
                    }
                }
                Button("Add alert") { showingAdd = true }
            }

            Section {
                Button {
                    Task {
                        guard let reminder = store.reminders.first else { return }
                        await NotificationManager.shared.requestAuth()
                        await NotificationManager.shared.sendBurstTest(reminder)
                    }
                } label: {
                    Label("Test notification burst", systemImage: "bell.badge")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) {
            AddReminderView(reminder: Reminder()) { store.upsert($0) }
        }
        .sheet(item: $editing) { reminder in
            AddReminderView(reminder: reminder) { store.upsert($0) }
        }
    }
}
