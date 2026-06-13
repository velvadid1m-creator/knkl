import UIKit

enum AppIconManager {
    private static let selectionKey = "selectedAppIcon.v1"

    /// Always use the main Shopify icon — clears old alternate "P" icons from earlier builds.
    @MainActor
    static func ensureShopifyIcon() async {
        UserDefaults.standard.removeObject(forKey: selectionKey)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        try? await UIApplication.shared.setAlternateIconName(nil)
    }
}
