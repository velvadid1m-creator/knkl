# Shopify — order notifications (iOS)

Sideload on Windows via GitHub Actions + Sideloadly. No Mac required.

## Quick install (Windows)

1. Push this repo to GitHub (or use the existing repo).
2. Go to **Actions** → **Build IPA** → wait ~2–3 min.
3. Download the **Shopify-ipa** artifact → get **`Shopify.ipa`**.
4. Install with **Sideloadly** (USB + Apple ID).

**Note:** Delete any old PingMe install from your phone first — the bundle ID is now `com.example.Shopify`.

## Build locally (Mac)

1. Open **`Shopify.xcodeproj`** in Xcode.
2. Select the **Shopify** target → set your Team and a unique bundle ID.
3. Archive or build for device, then package as `Shopify.ipa` for Sideloadly.

## Custom sounds

Import `.wav`, `.aiff`, `.caf`, `.m4a`, or `.mp3` (under 30 seconds) from inside the app.
