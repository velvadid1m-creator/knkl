import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: Store
    @State private var showingAdd = false
    @State private var editing: Reminder?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("PingMe")
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
        }
    }

    @ViewBuilder private var content: some View {
        if store.reminders.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 46))
                    .foregroundStyle(.secondary)
                Text("No notifications yet")
                    .font(.headline)
                Text("Tap + to create one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
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
}

private struct ReminderRow: View {
    @EnvironmentObject private var store: Store
    let reminder: Reminder

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title.isEmpty ? "Untitled" : reminder.title)
                    .font(.headline)
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
}
