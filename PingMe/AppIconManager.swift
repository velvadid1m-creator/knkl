import SwiftUI
import UIKit

struct AppIconChoice: Identifiable, Equatable {
    /// `nil` = the primary app icon.
    let iconName: String?
    let label: String
    let color: Color

    var id: String { iconName ?? "primary" }
}

enum AppIconManager {
    private static let selectionKey = "selectedAppIcon.v1"

    static let choices: [AppIconChoice] = [
        AppIconChoice(iconName: nil, label: "Purple", color: Color(red: 91/255, green: 95/255, blue: 234/255)),
        AppIconChoice(iconName: "AppIcon-Blue", label: "Blue", color: Color(red: 47/255, green: 128/255, blue: 237/255)),
        AppIconChoice(iconName: "AppIcon-Green", label: "Green", color: Color(red: 39/255, green: 174/255, blue: 96/255)),
        AppIconChoice(iconName: "AppIcon-Purple", label: "Violet", color: Color(red: 155/255, green: 81/255, blue: 224/255)),
        AppIconChoice(iconName: "AppIcon-Orange", label: "Orange", color: Color(red: 242/255, green: 153/255, blue: 74/255)),
        AppIconChoice(iconName: "AppIcon-Dark", label: "Dark", color: Color(red: 28/255, green: 28/255, blue: 30/255)),
        AppIconChoice(iconName: "AppIcon-Custom", label: "Custom", color: Color(red: 255/255, green: 105/255, blue: 180/255))
    ]

    static var selectedIconName: String? {
        get {
            let value = UserDefaults.standard.string(forKey: selectionKey)
            return value == "primary" ? nil : value
        }
        set {
            let stored = newValue ?? "primary"
            UserDefaults.standard.set(stored, forKey: selectionKey)
        }
    }

    static func apply(_ iconName: String?) async throws {
        guard UIApplication.shared.supportsAlternateIcons else {
            throw AppIconError.notSupported
        }
        try await UIApplication.shared.setAlternateIconName(iconName)
        selectedIconName = iconName
    }

    /// Saves a user image as a 1024×1024 PNG for the next app rebuild.
    static func saveCustomIconSource(_ image: UIImage) -> URL? {
        let canvas = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        let square = renderer.image { _ in
            let aspect = min(canvas.width / image.size.width, canvas.height / image.size.height)
            let size = CGSize(width: image.size.width * aspect, height: image.size.height * aspect)
            let origin = CGPoint(
                x: (canvas.width - size.width) / 2,
                y: (canvas.height - size.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: size))
        }
        guard let png = square.pngData() else { return nil }

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("my-app-icon.png")
        try? png.write(to: url)
        return url
    }
}

enum AppIconError: LocalizedError {
    case notSupported

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "This device does not support changing the app icon."
        }
    }
}
