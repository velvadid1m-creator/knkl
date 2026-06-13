import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: Store
    @State private var showingAdd = false
    @State private var editing: Reminder?
    @State private var logoImage: UIImage? = AppLogoStore.previewImage()

    var body: some View {
        NavigationStack {
            List {
                logoSection

                if store.reminders.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("No notifications yet")
                                .font(.headline)
                            Text("Tap + to create one. Every alert will use your app logo above.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Notifications") {
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
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                logoImage = AppLogoStore.previewImage()
                Task { await NotificationManager.shared.reschedule(store.reminders) }
            }
            .onAppear {
                logoImage = AppLogoStore.previewImage()
            }
        }
    }

    private var logoSection: some View {
        Section {
            AppLogoPicker(logoImage: $logoImage)
        } header: {
            Text("App logo")
        } footer: {
            Text("Pick one image — it shows on every notification instead of the default bell.")
        }
    }
}

private struct AppLogoPicker: View {
    @EnvironmentObject private var store: Store
    @Binding var logoImage: UIImage?

    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 16) {
            Group {
                if let logoImage {
                    Image(uiImage: logoImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.secondarySystemFill)
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(logoImage == nil ? "Choose app logo" : "Change app logo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if logoImage != nil {
                Button("Remove logo", role: .destructive) {
                    AppLogoStore.clear()
                    logoImage = nil
                    photoItem = nil
                    store.refreshNotifications()
                }
            }

            Button {
                Task {
                    await NotificationManager.shared.requestAuth()
                    await NotificationManager.shared.sendTest(
                        Reminder(title: "PingMe", body: "Preview of your notification logo")
                    )
                }
            } label: {
                Label("Test notification", systemImage: "paperplane")
            }
            .disabled(logoImage == nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onChange(of: photoItem) { _ in
            Task { await loadPickedImage() }
        }
    }

    private func loadPickedImage() async {
        guard let item = photoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let jpeg = image.jpegData(compressionQuality: 0.9) ?? data
        AppLogoStore.save(jpeg)
        logoImage = image
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
