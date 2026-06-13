import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: Store
    @State private var showingAdd = false
    @State private var editing: Reminder?

    var body: some View {
        NavigationStack {
            List {
                if store.reminders.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                            Text("No order alerts yet")
                                .font(.headline)
                            Text("Tap + to add one. A Shopify-style alert is added automatically.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Order alerts") {
                        ForEach(store.reminders) { reminder in
                            Button {
                                editing = reminder
                            } label: {
                                ReminderRow(reminder: reminder)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { store.reminders[$0] }
                            toDelete.forEach { store.delete($0) }
                        }
                    }
                }
            }
            .navigationTitle("Shopify")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
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
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task { await NotificationManager.shared.reschedule(store.reminders) }
            }
        }
    }
}

private struct ReminderRow: View {
    @EnvironmentObject private var store: Store
    let reminder: Reminder

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(previewTitle)
                    .font(.headline)
                    .lineLimit(2)
                if let previewSubtitle {
                    Text(previewSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Text(reminder.cadenceText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { reminder.isOn },
                set: { store.setOn(reminder, $0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var previewTitle: String {
        let counter = CounterStore.current(reminder.id) + 1
        let sampleDate = Date().addingTimeInterval(60)
        if reminder.title.isEmpty {
            return NotificationTemplate.render(
                reminder.body.isEmpty ? "Order alert" : reminder.body,
                counter: counter,
                fireDate: sampleDate
            )
        }
        return NotificationTemplate.render(reminder.title, counter: counter, fireDate: sampleDate)
    }

    private var previewSubtitle: String? {
        guard !reminder.title.isEmpty, !reminder.body.isEmpty else { return nil }
        let counter = CounterStore.current(reminder.id) + 1
        return NotificationTemplate.render(
            reminder.body,
            counter: counter,
            fireDate: Date().addingTimeInterval(60)
        )
    }
}
