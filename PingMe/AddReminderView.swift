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

    private var burstEveryRange: ClosedRange<Int> {
        switch reminder.burstEveryUnit {
        case .seconds: return 5...600
        case .minutes: return 1...999
        case .hours:   return 1...999
        case .days:    return 1...30
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
                        Button("Reset alert counter", role: .destructive) {
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
                    Text("Import .wav, .aiff, .caf, .m4a, or .mp3 files under 30 seconds. Custom sounds are copied into the app so they still play when Shopify is closed.")
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
                    Text("Normal timing")
                } footer: {
                    Text(reminder.usesDynamicText
                         ? "Between bursts, alerts vary — mostly every few minutes, sometimes up to a few hours."
                         : "Steady interval between single alerts when burst mode is off.")
                }

                Section {
                    Toggle("Burst mode", isOn: $reminder.burstEnabled)

                    if reminder.burstEnabled {
                        Stepper(value: $reminder.burstMinSeconds, in: 1...60) {
                            Text("From \(reminder.burstMinSeconds)s")
                        }
                        .onChange(of: reminder.burstMinSeconds) { _ in
                            if reminder.burstMaxSeconds < reminder.burstMinSeconds {
                                reminder.burstMaxSeconds = reminder.burstMinSeconds
                            }
                        }

                        Stepper(value: $reminder.burstMaxSeconds, in: reminder.burstMinSeconds...120) {
                            Text("To \(reminder.burstMaxSeconds)s")
                        }

                        Stepper(value: $reminder.burstCount, in: 2...12) {
                            Text("\(reminder.burstCount) alerts per burst")
                        }

                        Stepper(value: $reminder.burstEvery, in: burstEveryRange) {
                            Text("Burst every \(reminder.burstEvery)")
                        }
                        Picker("Burst unit", selection: $reminder.burstEveryUnit) {
                            ForEach(RepeatUnit.allCases) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        .onChange(of: reminder.burstEveryUnit) { _ in
                            reminder.burstEvery = min(reminder.burstEvery, burstEveryRange.upperBound)
                        }
                    }
                } header: {
                    Text("Burst")
                } footer: {
                    if reminder.burstEnabled {
                        let (lo, hi) = reminder.normalizedBurstSeconds
                        Text("Occasional rapid clusters — e.g. \(reminder.burstCount) orders \(lo)–\(hi) seconds apart, roughly every \(reminder.burstEvery) \(reminder.burstEveryUnit.label). Reopen the app to refill the next 64.")
                    } else {
                        Text("Turn on to occasionally fire a fast cluster of alerts. Reopen the app to refill the next 64.")
                    }
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
