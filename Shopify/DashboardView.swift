import SwiftUI

// MARK: - Theme

enum ShopifyTheme {
    static let green = Color(red: 0.0, green: 0.502, blue: 0.376)
    static let darkGreen = Color(red: 0.0, green: 0.345, blue: 0.255)
    static let background = Color(red: 0.965, green: 0.965, blue: 0.969)
    static let card = Color.white
    static let textPrimary = Color(red: 0.125, green: 0.133, blue: 0.137)
    static let textSecondary = Color(red: 0.427, green: 0.443, blue: 0.459)
    static let border = Color(red: 0.878, green: 0.878, blue: 0.878)
    static let success = Color(red: 0.0, green: 0.502, blue: 0.376)
    static let warning = Color(red: 0.737, green: 0.553, blue: 0.0)
}

// MARK: - Root shell

struct DashboardShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: Store
    @State private var selectedTab = 0

    private var orderCounter: Int {
        guard let reminder = store.reminders.first else { return 9 }
        return max(1, CounterStore.current(reminder.id))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardHomeView(orderCounter: orderCounter)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            DashboardOrdersView(orderCounter: orderCounter)
                .tabItem { Label("Orders", systemImage: "shippingbox.fill") }
                .tag(1)

            DashboardProductsView()
                .tabItem { Label("Products", systemImage: "tag.fill") }
                .tag(2)

            DashboardAlertsView()
                .tabItem { Label("Alerts", systemImage: "bell.badge.fill") }
                .tag(3)
        }
        .tint(ShopifyTheme.green)
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await NotificationManager.shared.reschedule(store.reminders) }
        }
    }
}

// MARK: - Shared chrome

private struct DashboardHeader: View {
    let title: String
    var showsStore: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    if showsStore {
                        Text(ShopifySampleData.defaultStore)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ShopifyTheme.textSecondary)
                    }
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(ShopifyTheme.textPrimary)
                }
                Spacer()
                Image(systemName: "bag.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(ShopifyTheme.darkGreen, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ShopifyTheme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(ShopifyTheme.textPrimary)
            Text(footnote)
                .font(.caption2)
                .foregroundStyle(ShopifyTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ShopifyTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ShopifyTheme.border, lineWidth: 1)
        )
    }
}

private struct OrderRow: View {
    let order: DashboardOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Order #\(order.orderNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShopifyTheme.textPrimary)
                Spacer()
                Text(DashboardData.relativeTime(order.placedAt))
                    .font(.caption)
                    .foregroundStyle(ShopifyTheme.textSecondary)
            }
            Text(order.subtitleLine)
                .font(.subheadline)
                .foregroundStyle(ShopifyTheme.textSecondary)
            Text(order.store)
                .font(.subheadline)
                .foregroundStyle(ShopifyTheme.textPrimary)
            HStack(spacing: 8) {
                StatusPill(text: order.status, color: ShopifyTheme.success)
                StatusPill(
                    text: order.fulfillment,
                    color: order.fulfillment == "Unfulfilled" ? ShopifyTheme.warning : ShopifyTheme.textSecondary
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Home

struct DashboardHomeView: View {
    let orderCounter: Int

    private var stats: DashboardStats {
        DashboardData.todayStats(counter: orderCounter)
    }

    private var recentOrders: [DashboardOrder] {
        Array(DashboardData.recentOrders(counter: orderCounter, limit: 6).prefix(6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DashboardHeader(title: "Today")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Performance")
                            .font(.headline)
                            .foregroundStyle(ShopifyTheme.textPrimary)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(title: "Total sales", value: stats.totalSales, footnote: "Today")
                            StatCard(title: "Orders", value: "\(stats.orderCount)", footnote: "Online Store")
                            StatCard(title: "Sessions", value: "\(stats.sessions)", footnote: "Store visitors")
                            StatCard(title: "Conversion", value: String(format: "%.1f%%", stats.conversionRate), footnote: "Added to cart")
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Recent orders")
                                .font(.headline)
                            Spacer()
                            Text("View all")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(ShopifyTheme.green)
                        }
                        .foregroundStyle(ShopifyTheme.textPrimary)
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(recentOrders) { order in
                                OrderRow(order: order)
                                if order.id != recentOrders.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(14)
                        .background(ShopifyTheme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ShopifyTheme.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Store")
                            .font(.headline)
                            .foregroundStyle(ShopifyTheme.textPrimary)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ShopifySampleData.defaultStore)
                                    .font(.subheadline.weight(.semibold))
                                Text("novuskits.myshopify.com")
                                    .font(.caption)
                                    .foregroundStyle(ShopifyTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ShopifyTheme.textSecondary)
                        }
                        .padding(14)
                        .background(ShopifyTheme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ShopifyTheme.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .background(ShopifyTheme.background)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Orders

struct DashboardOrdersView: View {
    let orderCounter: Int
    @State private var filter = "All"

    private let filters = ["All", "Unfulfilled", "Paid", "Fulfilled"]

    private var orders: [DashboardOrder] {
        let all = DashboardData.recentOrders(counter: orderCounter, limit: 32)
        switch filter {
        case "Unfulfilled": return all.filter { $0.fulfillment == "Unfulfilled" }
        case "Paid": return all.filter { $0.status == "Paid" }
        case "Fulfilled": return all.filter { $0.fulfillment == "Fulfilled" }
        default: return all
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DashboardHeader(title: "Orders")
                    .padding(.bottom, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { item in
                            Button {
                                filter = item
                            } label: {
                                Text(item)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(filter == item ? .white : ShopifyTheme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        filter == item ? ShopifyTheme.green : ShopifyTheme.card,
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule().stroke(ShopifyTheme.border, lineWidth: filter == item ? 0 : 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)

                List {
                    ForEach(orders) { order in
                        OrderRow(order: order)
                            .listRowBackground(ShopifyTheme.card)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(ShopifyTheme.background)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Products

struct DashboardProductsView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                DashboardHeader(title: "Products")
                    .padding(.bottom, 12)

                List {
                    Section {
                        ForEach(DashboardData.products) { product in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ShopifyTheme.background)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "cube.box.fill")
                                            .foregroundStyle(ShopifyTheme.green)
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(product.price) · \(product.inventory) in stock")
                                        .font(.caption)
                                        .foregroundStyle(ShopifyTheme.textSecondary)
                                }
                                Spacer()
                                StatusPill(text: product.status, color: ShopifyTheme.success)
                            }
                            .listRowBackground(ShopifyTheme.card)
                        }
                    } header: {
                        Text("\(DashboardData.products.count) products")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(ShopifyTheme.background)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Alerts (notification settings)

struct DashboardAlertsView: View {
    @EnvironmentObject private var store: Store
    @State private var showingAdd = false
    @State private var editing: Reminder?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                DashboardHeader(title: "Order alerts", showsStore: false)
                    .padding(.bottom, 12)

                if store.reminders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 40))
                            .foregroundStyle(ShopifyTheme.green)
                        Text("No alerts configured")
                            .font(.headline)
                        Text("Add an alert to receive Shopify-style order notifications.")
                            .font(.subheadline)
                            .foregroundStyle(ShopifyTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Add alert") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                            .tint(ShopifyTheme.green)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        Section("Active alerts") {
                            ForEach(store.reminders) { reminder in
                                Button {
                                    editing = reminder
                                } label: {
                                    AlertReminderRow(reminder: reminder)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                offsets.map { store.reminders[$0] }.forEach { store.delete($0) }
                            }
                        }

                        Section {
                            Button {
                                Task {
                                    guard let reminder = store.reminders.first else { return }
                                    await NotificationManager.shared.requestAuth()
                                    await NotificationManager.shared.sendBurstTest(reminder)
                                }
                            } label: {
                                Label("Test burst now", systemImage: "bell.badge")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(ShopifyTheme.background)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddReminderView(reminder: Reminder()) { store.upsert($0) }
            }
            .sheet(item: $editing) { reminder in
                AddReminderView(reminder: reminder) { store.upsert($0) }
            }
        }
    }
}

private struct AlertReminderRow: View {
    @EnvironmentObject private var store: Store
    let reminder: Reminder

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(previewTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let previewSubtitle {
                    Text(previewSubtitle)
                        .font(.caption)
                        .foregroundStyle(ShopifyTheme.textSecondary)
                        .lineLimit(2)
                }
                Text(reminder.cadenceText)
                    .font(.caption2)
                    .foregroundStyle(ShopifyTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { reminder.isOn },
                set: { store.setOn(reminder, $0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private var previewTitle: String {
        let counter = CounterStore.current(reminder.id) + 1
        let raw = reminder.title.isEmpty ? "Order" : reminder.title
        return NotificationTemplate.render(raw, counter: counter, fireDate: Date().addingTimeInterval(60))
    }

    private var previewSubtitle: String? {
        guard !reminder.body.isEmpty else { return nil }
        let counter = CounterStore.current(reminder.id) + 1
        return NotificationTemplate.render(reminder.body, counter: counter, fireDate: Date().addingTimeInterval(60))
    }
}
