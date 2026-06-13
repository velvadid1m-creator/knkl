import SwiftUI
import PhotosUI
import UIKit

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reminder: Reminder
    private let onSave: (Reminder) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?

    init(reminder: Reminder, onSave: @escaping (Reminder) -> Void) {
        _reminder = State(initialValue: reminder)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextField("Title", text: $reminder.title)
                    TextField("Text", text: $reminder.body, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Sound") {
                    Picker("Sound", selection: $reminder.soundName) {
                        ForEach(availableSounds) { sound in
                            Text(sound.label).tag(sound.fileName)
                        }
                    }
                }

                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(reminder.imageFileName == nil ? "Choose image" : "Change image",
                              systemImage: "photo")
                    }
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if reminder.imageFileName != nil {
                        Button("Remove image", role: .destructive) {
                            if let name = reminder.imageFileName { ImageStore.delete(name) }
                            reminder.imageFileName = nil
                            previewImage = nil
                            photoItem = nil
                        }
                    }
                } header: {
                    Text("Image")
                } footer: {
                    Text("Shows inside the notification. The small corner badge is always the app's own icon — that's an iOS rule, not changeable per notification.")
                }

                Section {
                    Stepper(value: $reminder.every, in: 1...999) {
                        Text("Every \(reminder.every)")
                    }
                    Picker("Unit", selection: $reminder.unit) {
                        ForEach(RepeatUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                } header: {
                    Text("How often")
                } footer: {
                    Text("iPhone repeats no faster than once a minute, and keeps your 64 most imminent notifications scheduled at a time.")
                }

                Section {
                    Button {
                        Task {
                            await NotificationManager.shared.requestAuth()
                            await NotificationManager.shared.sendTest(reminder)
                        }
                    } label: {
                        Label("Send a test now", systemImage: "paperplane")
                    }
                }
            }
            .navigationTitle("Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(reminder)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: photoItem) { _ in
                Task { await loadPickedImage() }
            }
            .task {
                await loadExistingPreview()
            }
        }
    }

    private func loadPickedImage() async {
        guard let item = photoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let jpeg = image.jpegData(compressionQuality: 0.9) ?? data
        if let old = reminder.imageFileName { ImageStore.delete(old) }
        reminder.imageFileName = ImageStore.save(jpeg, ext: "jpg")
        previewImage = image
    }

    private func loadExistingPreview() async {
        guard previewImage == nil,
              let name = reminder.imageFileName,
              let data = try? Data(contentsOf: ImageStore.url(name)),
              let image = UIImage(data: data) else { return }
        previewImage = image
    }
}
