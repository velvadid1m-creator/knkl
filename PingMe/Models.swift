import Foundation
import UserNotifications
import Intents
import UIKit

// MARK: - Repeat unit

enum RepeatUnit: String, Codable, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours
    case days

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        case .hours:   return 3600
        case .days:    return 86400
        }
    }

    var label: String {
        switch self {
        case .seconds: return "seconds"
        case .minutes: return "minutes"
        case .hours:   return "hours"
        case .days:    return "days"
        }
    }
}

// MARK: - Reminder model

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var soundName: String = "chime.wav"   // "" == system default
    var imageFileName: String? = nil
    var every: Int = 1
    var unit: RepeatUnit = .hours
    var isOn: Bool = true

    var intervalSeconds: TimeInterval {
        Double(max(1, every)) * unit.seconds
    }

    var cadenceText: String {
        let word: String
        switch unit {
        case .seconds: word = every == 1 ? "second" : "seconds"
        case .minutes: word = every == 1 ? "minute" : "minutes"
        case .hours:   word = every == 1 ? "hour" : "hours"
        case .days:    word = every == 1 ? "day" : "days"
        }
        return "Every \(every) \(word)"
    }
}

// MARK: - Sound choices (filenames must match files bundled in the app)

struct SoundOption: Identifiable, Hashable {
    var id: String { fileName }
    let fileName: String   // "" == default
    let label: String
}

let bundledSounds: [SoundOption] = [
    SoundOption(fileName: "",          label: "Default"),
    SoundOption(fileName: "chime.wav", label: "Chime"),
    SoundOption(fileName: "ding.wav",  label: "Ding"),
    SoundOption(fileName: "bell.wav",  label: "Bell"),
    SoundOption(fileName: "alarm.wav", label: "Alarm")
]

enum SoundStore {
    private static let listKey = "customSounds.v1"
    private static let allowedExtensions = ["wav", "aiff", "aif", "caf", "m4a", "mp3"]

    static var soundsDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let folder = library.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static var customFileNames: [String] {
        get { UserDefaults.standard.stringArray(forKey: listKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: listKey) }
    }

    static func allOptions() -> [SoundOption] {
        let custom = customFileNames.map { name in
            SoundOption(fileName: name, label: name)
        }
        return bundledSounds + custom
    }

    @discardableResult
    static func importSound(from source: URL) throws -> String {
        let ext = source.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else {
            throw SoundImportError.unsupportedType
        }

        let base = source.deletingPathExtension().lastPathComponent
        let safeBase = base.isEmpty ? "custom" : String(base.prefix(40))
        var fileName = "\(safeBase).\(ext)"
        var destination = soundsDirectory.appendingPathComponent(fileName)
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            fileName = "\(safeBase)-\(counter).\(ext)"
            destination = soundsDirectory.appendingPathComponent(fileName)
            counter += 1
        }

        if source.startAccessingSecurityScopedResource() {
            defer { source.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            try FileManager.default.copyItem(at: source, to: destination)
        }

        if !customFileNames.contains(fileName) {
            customFileNames.append(fileName)
        }
        return fileName
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: soundsDirectory.appendingPathComponent(fileName))
        customFileNames.removeAll { $0 == fileName }
    }
}

enum SoundImportError: LocalizedError {
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Use a .wav, .aiff, .caf, .m4a, or .mp3 file under 30 seconds."
        }
    }
}

// MARK: - Image storage (Documents/images)

enum ImageStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func url(_ name: String) -> URL {
        dir.appendingPathComponent(name)
    }

    @discardableResult
    static func save(_ data: Data, ext: String = "jpg") -> String {
        let name = UUID().uuidString + "." + ext
        try? data.write(to: url(name))
        return name
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
        try? FileManager.default.removeItem(at: avatarsDirectory.appendingPathComponent(name))
    }

    /// Square PNG copy for notification avatars — iOS reads these more reliably than raw camera JPEGs.
    static func notificationAvatarURL(for source: URL) -> URL? {
        guard let data = try? Data(contentsOf: source),
              let image = UIImage(data: data) else { return nil }

        let side = min(image.size.width, image.size.height)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let square = renderer.image { _ in
            image.draw(in: CGRect(
                x: (side - image.size.width) / 2,
                y: (side - image.size.height) / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
        guard let png = square.pngData() else { return source }

        let name = source.lastPathComponent + ".avatar.png"
        let destination = avatarsDirectory.appendingPathComponent(name)
        try? png.write(to: destination)
        return destination
    }

    private static var avatarsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    @Published var reminders: [Reminder] = []

    private let key = "reminders.v1"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data) else { return }
        reminders = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func upsert(_ reminder: Reminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.append(reminder)
        }
        save()
        reschedule()
    }

    func delete(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
        if let name = reminder.imageFileName { ImageStore.delete(name) }
        save()
        reschedule()
    }

    func setOn(_ reminder: Reminder, _ on: Bool) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index].isOn = on
        save()
        reschedule()
    }

    private func reschedule() {
        let snapshot = reminders
        Task { await NotificationManager.shared.reschedule(snapshot) }
    }
}

// MARK: - Notifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let foreground = ForegroundDelegate()

    private init() {
        center.delegate = foreground
    }

    @discardableResult
    func requestAuth() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private let maxPending = 64

    func reschedule(_ reminders: [Reminder]) async {
        center.removeAllPendingNotificationRequests()

        let active = reminders.filter(\.isOn)
        guard !active.isEmpty else { return }

        let slow = active.filter { $0.intervalSeconds >= 60 }
        let fast = active.filter { $0.intervalSeconds < 60 }
        let burstSlots = max(0, maxPending - slow.count)

        for reminder in slow {
            await scheduleRepeating(reminder)
        }

        guard burstSlots > 0, !fast.isEmpty else { return }

        let perReminder = max(1, burstSlots / fast.count)
        for reminder in fast {
            await scheduleBurst(reminder, count: perReminder)
        }
    }

    private func scheduleRepeating(_ reminder: Reminder) async {
        let content = await makeContent(for: reminder, fallbackTitle: "Reminder")
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// iOS won't repeat faster than 60s, so queue many one-shot alerts instead.
    private func scheduleBurst(_ reminder: Reminder, count: Int) async {
        let interval = max(1, reminder.intervalSeconds)
        let content = await makeContent(for: reminder, fallbackTitle: "Reminder")

        for index in 1...count {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval * Double(index), repeats: false)
            let identifier = "\(reminder.id.uuidString)-\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Fires once, ~2 seconds out, so you can preview a notification.
    func sendTest(_ reminder: Reminder) async {
        var content = await makeContent(for: reminder, fallbackTitle: "Test")
        if content.body.isEmpty { content.body = "This is a test" }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test-" + UUID().uuidString, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func makeContent(for reminder: Reminder, fallbackTitle: String) async -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let title = reminder.title.isEmpty ? fallbackTitle : reminder.title
        content.title = title
        content.body = reminder.body
        content.threadIdentifier = reminder.id.uuidString
        content.sound = reminder.soundName.isEmpty
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(reminder.soundName))

        guard let name = reminder.imageFileName else { return content }

        let fileURL = ImageStore.url(name)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return content }

        return await applyCommunicationAvatar(
            to: content,
            imageURL: fileURL,
            displayName: title,
            conversationID: reminder.id.uuidString
        )
    }

    /// Shows the picked image as the large left-side notification avatar (Messages-style).
    private func applyCommunicationAvatar(
        to content: UNMutableNotificationContent,
        imageURL: URL,
        displayName: String,
        conversationID: String
    ) async -> UNMutableNotificationContent {
        let avatarURL = ImageStore.notificationAvatarURL(for: imageURL) ?? imageURL
        let handle = INPersonHandle(value: conversationID, type: .unknown)
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: displayName,
            image: INImage(url: avatarURL),
            contactIdentifier: nil,
            customIdentifier: conversationID,
            isMe: false,
            suggestionType: .none
        )

        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: nil,
            conversationIdentifier: conversationID,
            serviceName: "PingMe",
            sender: sender,
            attachments: nil
        )

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming

        do {
            try await interaction.donate()
            let updated = try content.updating(from: intent)
            if let mutable = updated.mutableCopy() as? UNMutableNotificationContent {
                mutable.sound = content.sound
                mutable.threadIdentifier = content.threadIdentifier
                return mutable
            }
        } catch {
            // Fall through to attachment preview if communication style isn't available.
        }

        return attachImageFallback(to: content, imageURL: avatarURL, identifier: conversationID)
    }

    private func attachImageFallback(
        to content: UNMutableNotificationContent,
        imageURL: URL,
        identifier: String
    ) -> UNMutableNotificationContent {
        let rect: [String: NSNumber] = ["X": 0, "Y": 0, "Width": 1, "Height": 1]
        if let attachment = try? UNNotificationAttachment(
            identifier: identifier,
            url: imageURL,
            options: [UNNotificationAttachmentOptionsThumbnailClippingRectKey: rect]
        ) {
            content.attachments = [attachment]
        }
        return content
    }
}

/// Lets notifications show (with sound) even while the app is open — handy for the test button.
final class ForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
