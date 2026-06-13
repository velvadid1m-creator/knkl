import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reminder: Reminder
    private let onSave: (Reminder) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var soundOptions = SoundStore.allOptions()
    @State private var showingSoundImporter = false
    @State private var soundImportError: String?

    init(reminder: Reminder, onSave: @escaping (Reminder) -> Void) {
        _reminder = State(initialValue: reminder)
        self.onSave = onSave
    }

    private var everyRange: ClosedRange<Int> {
        switch reminder.unit {
        case .seconds: return 1...300
        case .minutes: return 1...999
        case .hours:   return 1...999
        case .days:    return 1...999
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextField("Title", text: $reminder.title)
                    TextField("Text", text: $reminder.body, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    Picker("Sound", selection: $reminder.soundName) {
                        ForEach(soundOptions) { sound in
                            Text(sound.label).tag(sound.fileName)
                        }
                    }
                    Button {
                        showingSoundImporter = true
                    } label: {
                        Label("Import custom sound", systemImage: "square.and.arrow.down")
                    }
                    if reminder.soundName.isEmpty == false,
                       SoundStore.customFileNames.contains(reminder.soundName) {
                        Button("Delete custom sound", role: .destructive) {
                            SoundStore.delete(reminder.soundName)
                            reminder.soundName = ""
                            refreshSoundOptions()
                        }
                    }
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Import .wav, .aiff, .caf, .m4a, or .mp3 files under 30 seconds. Custom sounds are copied into the app so they still play when PingMe is closed.")
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
                    Stepper(value: $reminder.every, in: everyRange) {
                        Text("Every \(reminder.every)")
                    }
                    Picker("Unit", selection: $reminder.unit) {
                        ForEach(RepeatUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .onChange(of: reminder.unit) { _ in
                        reminder.every = min(reminder.every, everyRange.upperBound)
                    }
                } header: {
                    Text("How often")
                } footer: {
                    Text("Intervals under 1 minute queue as many alerts as iOS allows (up to 64). Re-open PingMe to refill the queue after they run out.")
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
                refreshSoundOptions()
            }
            .fileImporter(
                isPresented: $showingSoundImporter,
                allowedContentTypes: [.wav, .aiff, .audio, .mp3],
                allowsMultipleSelection: false
            ) { result in
                handleSoundImport(result)
            }
            .alert("Couldn't import sound", isPresented: Binding(
                get: { soundImportError != nil },
                set: { if !$0 { soundImportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(soundImportError ?? "")
            }
        }
    }

    private func refreshSoundOptions() {
        soundOptions = SoundStore.allOptions()
    }

    private func handleSoundImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            soundImportError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let fileName = try SoundStore.importSound(from: url)
                refreshSoundOptions()
                reminder.soundName = fileName
            } catch {
                soundImportError = error.localizedDescription
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
