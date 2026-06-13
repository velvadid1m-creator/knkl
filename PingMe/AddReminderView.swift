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

    private var burstGapDescription: String {
        let (lo, hi) = reminder.normalizedBurstSeconds
        if lo == hi { return "\(lo)s apart" }
        return "\(lo)–\(hi)s apart"
    }

    private var burstPreviewText: String {
        let (lo, hi) = reminder.normalizedBurstSeconds
        let gap = lo == hi ? "\(lo)s" : "\(lo)–\(hi)s"
        let span = lo == hi
            ? max(0, (reminder.burstCount - 1) * lo)
            : (reminder.burstCount - 1) * hi
        return "\(reminder.burstCount)× in ~\(span)s · every \(reminder.burstEvery) \(reminder.burstEveryUnit.label)"
    }

    @ViewBuilder
    private func spacingField(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        onChange: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - spacingStep(for: value.wrappedValue))
                onChange?()
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 2) {
                TextField("sec", value: value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .onChange(of: value.wrappedValue) { newValue in
                        value.wrappedValue = min(range.upperBound, max(range.lowerBound, newValue))
                        onChange?()
                    }
                Text(Reminder.formatDuration(value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + spacingStep(for: value.wrappedValue))
                onChange?()
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private func spacingStep(for seconds: Int) -> Int {
        switch seconds {
        case ..<60: return 1
        case ..<600: return 10
        case ..<3600: return 30
        default: return 300
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
                    spacingField(
                        label: "Shortest gap",
                        value: $reminder.spacingMinSeconds,
                        range: 1...reminder.spacingMaxSeconds
                    ) {
                        if reminder.spacingMaxSeconds < reminder.spacingMinSeconds {
                            reminder.spacingMaxSeconds = reminder.spacingMinSeconds
                        }
                    }

                    spacingField(
                        label: "Longest gap",
                        value: $reminder.spacingMaxSeconds,
                        range: reminder.spacingMinSeconds...86400
                    )

                    HStack {
                        Text("Preview")
                        Spacer()
                        Text("\(Reminder.formatDuration(reminder.normalizedSpacingSeconds.min)) – \(Reminder.formatDuration(reminder.normalizedSpacingSeconds.max))")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Varied spacing")
                } footer: {
                    Text("Each normal alert waits a random number of seconds between your shortest and longest gap.")
                }

                Section {
                    Toggle("Burst mode", isOn: $reminder.burstEnabled)

                    if reminder.burstEnabled {
                        spacingField(
                            label: "Burst gap from",
                            value: $reminder.burstMinSeconds,
                            range: 1...reminder.burstMaxSeconds
                        ) {
                            if reminder.burstMaxSeconds < reminder.burstMinSeconds {
                                reminder.burstMaxSeconds = reminder.burstMinSeconds
                            }
                        }

                        spacingField(
                            label: "Burst gap to",
                            value: $reminder.burstMaxSeconds,
                            range: reminder.burstMinSeconds...60
                        )

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

                        HStack {
                            Text("Burst preview")
                            Spacer()
                            Text(burstPreviewText)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("Burst")
                } footer: {
                    if reminder.burstEnabled {
                        Text("A burst fires \(reminder.burstCount) alerts \(burstGapDescription). iOS needs at least 1 second between alerts, so 3× with 1s gap lands in about 2 seconds. Reopen the app to refill the next 64.")
                    } else {
                        Text("Turn on for occasional rapid clusters between normal varied alerts.")
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
