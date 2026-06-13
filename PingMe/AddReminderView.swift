import SwiftUI
import UniformTypeIdentifiers

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reminder: Reminder
    private let onSave: (Reminder) -> Void

    @State private var soundOptions = SoundStore.allOptions()
    @State private var showingSoundImporter = false
    @State private var soundImportError: String?
    @FocusState private var focusedField: MessageField?

    private enum MessageField {
        case title, body
    }

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
                        .focused($focusedField, equals: .title)
                    TextField("Text", text: $reminder.body, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focusedField, equals: .body)
                }

                Section {
                    Button {
                        let id = reminder.id
                        reminder = Reminder.shopifyOrder
                        reminder.id = id
                    } label: {
                        Label("Use Shopify order template", systemImage: "bag")
                    }

                    ForEach(NotificationTemplate.insertable, id: \.token) { item in
                        Button {
                            insertToken(item.token)
                        } label: {
                            HStack {
                                Text(item.label)
                                Spacer()
                                Text(item.token)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if reminder.usesDynamicText {
                        Button("Reset order # to 1001", role: .destructive) {
                            CounterStore.reset(reminder.id)
                        }
                    }
                } header: {
                    Text("Variables")
                } footer: {
                    Text(NotificationTemplate.variableHelp)
                }

                if reminder.usesDynamicText {
                    Section("Preview") {
                        let counter = CounterStore.current(reminder.id) + 1
                        let sampleDate = Date().addingTimeInterval(60)
                        LabeledContent("Title") {
                            Text(NotificationTemplate.render(
                                reminder.title.isEmpty ? "Reminder" : reminder.title,
                                counter: counter,
                                fireDate: sampleDate
                            ))
                        }
                        LabeledContent("Text") {
                            Text(NotificationTemplate.render(reminder.body, counter: counter, fireDate: sampleDate))
                        }
                    }
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
                    Text("Shopify-style variables change each alert. iOS keeps up to 64 upcoming — reopen PingMe to refill.")
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
            .task {
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

    private func insertToken(_ token: String) {
        switch focusedField {
        case .title:
            reminder.title += token
        case .body, .none:
            reminder.body += token
        }
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
}
