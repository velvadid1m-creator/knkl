# Shopify — merchant app (iOS)

Sideload on Windows via GitHub Actions + Sideloadly. No Mac required.

## Quick install (Windows)

1. Push this repo to GitHub (or use the existing repo).
2. Go to **Actions** → **Build IPA** → wait ~2–3 min.
3. Download the **Shopify-ipa** artifact → unzip to get **`Shopify.ipa`**.
4. Delete any old apps from your phone (including previous installs).
5. Install **`Shopify.ipa`** with **Sideloadly** (USB + Apple ID).

**Bundle ID:** `com.shopify.novuskits.merchant` — this is a fresh Shopify app identity.

## Build locally (Mac)

1. Open **`Shopify.xcodeproj`** in Xcode.
2. Select the **Shopify** target → set your Team.
3. Archive or build for device, then package as `Shopify.ipa` for Sideloadly.

## Custom sounds

Import `.wav`, `.aiff`, `.caf`, `.m4a`, or `.mp3` (under 30 seconds) from inside the app.
