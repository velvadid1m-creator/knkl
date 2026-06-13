import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: Store
    @State private var showingAdd = false
    @State private var showingLogo = false
    @State private var editing: Reminder?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("PingMe")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingLogo = true
                        } label: {
                            Image(systemName: "photo.circle")
                        }
                    }
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
                .sheet(isPresented: $showingLogo) {
                    AppLogoView()
                        .environmentObject(store)
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task { await NotificationManager.shared.reschedule(store.reminders) }
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
                Text("Tap the photo icon to set your notification logo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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

private struct AppLogoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: Store

    @State private var photoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(AppLogoStore.hasLogo ? "Change logo" : "Choose logo", systemImage: "photo")
                    }
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if AppLogoStore.hasLogo {
                        Button("Remove logo", role: .destructive) {
                            AppLogoStore.clear()
                            previewImage = nil
                            photoItem = nil
                            store.refreshNotifications()
                        }
                    }
                } header: {
                    Text("Notification logo")
                } footer: {
                    Text("One logo for all notifications. It shows as the big round icon on the left of every alert.")
                }

                Section {
                    Button {
                        Task {
                            await NotificationManager.shared.requestAuth()
                            await NotificationManager.shared.sendTest(Reminder(title: "Logo test", body: "Checking your logo"))
                        }
                    } label: {
                        Label("Send a test notification", systemImage: "paperplane")
                    }
                }
            }
            .navigationTitle("App Logo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _ in
                Task { await loadPickedImage() }
            }
            .onAppear {
                previewImage = AppLogoStore.previewImage()
            }
        }
    }

    private func loadPickedImage() async {
        guard let item = photoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let jpeg = image.jpegData(compressionQuality: 0.9) ?? data
        AppLogoStore.save(jpeg)
        previewImage = image
        store.refreshNotifications()
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
