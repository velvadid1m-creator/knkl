import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: Store
    @State private var showingAdd = false
    @State private var editing: Reminder?
    @State private var selectedIconName: String? = AppIconManager.selectedIconName
    @State private var iconError: String?
    @State private var customPhotoItem: PhotosPickerItem?
    @State private var customIconPreview: UIImage?
    @State private var customIconSaved = false

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            List {
                appIconSection

                if store.reminders.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("No notifications yet")
                                .font(.headline)
                            Text("Tap + to create one.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                Task { await NotificationManager.shared.reschedule(store.reminders) }
            }
            .onChange(of: customPhotoItem) { _ in
                Task { await importCustomIcon() }
            }
            .alert("Couldn't change icon", isPresented: Binding(
                get: { iconError != nil },
                set: { if !$0 { iconError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(iconError ?? "")
            }
        }
    }

    private var appIconSection: some View {
        Section {
            LazyVGrid(columns: iconColumns, spacing: 12) {
                ForEach(AppIconManager.choices) { choice in
                    Button {
                        Task { await selectIcon(choice.iconName) }
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(choice.color)
                                .frame(width: 58, height: 58)
                                .overlay {
                                    if isSelected(choice.iconName) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .shadow(radius: 2)
                                    }
                                }
                            Text(choice.label)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            PhotosPicker(selection: $customPhotoItem, matching: .images) {
                Label("Use my own image", systemImage: "photo.on.rectangle.angled")
            }

            if let customIconPreview {
                Image(uiImage: customIconPreview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if customIconSaved {
                Text("Image saved. Reinstall the app once with this image baked in, then pick Custom above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("App icon")
        } footer: {
            Text("Changes the home screen icon and the small icon on notifications. Preset colors switch instantly. Your own image needs one reinstall to bake it in.")
        }
    }

    private func isSelected(_ iconName: String?) -> Bool {
        selectedIconName == iconName
    }

    private func selectIcon(_ iconName: String?) async {
        do {
            try await AppIconManager.apply(iconName)
            selectedIconName = iconName
        } catch {
            iconError = error.localizedDescription
        }
    }

    private func importCustomIcon() async {
        guard let item = customPhotoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        customIconPreview = image
        customIconSaved = AppIconManager.saveCustomIconSource(image) != nil

        do {
            try await AppIconManager.apply("AppIcon-Custom")
            selectedIconName = "AppIcon-Custom"
        } catch {
            iconError = error.localizedDescription
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
