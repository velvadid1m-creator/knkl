import UIKit

enum AppIconManager {
    private static let legacyKeys = [
        "selectedAppIcon.v1",
        "reminders.v1",
        "shopify.merchant.reminders.v1",
        "seeded.shopify.v3",
        "seeded.shopify.v2",
        "seeded.shopify.v1",
        "shopify.merchant.seeded.v1",
    ]

    @MainActor
    static func ensureShopifyIcon() async {
        for key in legacyKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        try? await UIApplication.shared.setAlternateIconName(nil)
    }
}
