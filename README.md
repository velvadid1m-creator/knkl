# PingMe — custom local notifications (iOS)

A tiny SwiftUI app. Make as many notifications as you want, each with its own
title, text, sound, image, and repeat interval. Everything is local/on-device —
no server, no paid Apple Developer account. Custom sounds play even when the app
is closed (that's why it's a native app and not a website).

Four custom sounds are already bundled (Chime, Ding, Bell, Alarm), plus an app icon.

---

## Don't want to touch the Mac? Build the .ipa in the cloud (Windows-only path)

The Swift code has to be compiled by Xcode *somewhere* — but it doesn't have to be
your VM. A free GitHub macOS runner can do it and hand you a finished `.ipa`:

1. Make a free GitHub account and a new repo. Upload everything in this folder to it (keep the folder structure).
2. Open the repo's **Actions** tab → **Build IPA** → **Run workflow**.
3. Wait ~2-3 min. Open the finished run and download the **PingMe-ipa** artifact at the bottom. Unzip it to get **`PingMe.ipa`**.
4. Feed `PingMe.ipa` to **Sideloadly** on Windows (your IPA slot in the screenshot) — it signs with your Apple ID and installs. Done, no Mac involved.

The workflow builds it **unsigned** on purpose, because Sideloadly does the signing.
Everything below is the alternative if you'd rather build locally in the VM.

---

## Build it (in your macOS VM) and put it on your iPhone

1. Copy this whole `PingMe` folder into the macOS VM.
2. Open **`PingMe.xcodeproj`** in Xcode.
3. Click the **PingMe** target → **Signing & Capabilities** tab:
   - Tick **Automatically manage signing**.
   - Under **Team**, pick your Apple ID (a free one is fine — add it in Xcode → Settings → Accounts if it's not listed).
   - Change **Bundle Identifier** to something unique, e.g. `com.yourname.pingme`.
4. At the top of the window set the run destination to **Any iOS Device (arm64)**, then **Product → Build** (⌘B).
5. Turn the built app into a `.ipa`:
   - In the left sidebar open **Products**, right-click **PingMe.app → Show in Finder**.
   - Make a new folder called **`Payload`** (capital P), drag `PingMe.app` inside it.
   - Right-click the `Payload` folder → **Compress**. Rename the resulting `Payload.zip` to **`PingMe.ipa`**.
6. Move `PingMe.ipa` to your Windows PC and install it with **AltStore** or **Sideloadly** over USB. They re-sign it with your Apple ID automatically.
7. On the iPhone, open the app and tap **Allow** when it asks about notifications.

> Apps signed with a free Apple ID stop working after 7 days. AltStore can auto-refresh them over Wi-Fi so you don't have to redo this.

---

## Using it
- Tap **+**, type a title and text, pick a sound, optionally pick an image, set how often it repeats, tap **Save**.
- **Send a test now** fires the notification in ~2 seconds so you can check it.
- The toggle on each row turns a notification off without deleting it. Swipe left to delete.

## Add your own sound
Drop a short audio file (**.wav / .aiff / .caf**, **under 30 seconds**) into the `PingMe`
source folder, then drag it into the project in Xcode (tick *Copy items if needed* and
the *PingMe* target). Add its filename to the `availableSounds` list near the top of
`Models.swift`. iOS only plays notification sounds that are bundled inside the app — there's no way around shipping the file.

---

## Three iOS facts worth knowing (not bugs)
- **The small corner badge on a notification is always the app's own icon.** iOS doesn't let any app change that per notification. The image you pick shows *inside* the notification — as the thumbnail on the right, and full-size when you long-press/expand it.
- **Minimum repeat is once per minute**, and iOS keeps only your **64 most imminent** notifications scheduled at a time. Fine for normal use.
- **No sound on silent.** If the ringer switch is on silent, or a Focus/Do Not Disturb is blocking the app, the custom sound won't play — that's iOS, not the app.

---

## If `PingMe.xcodeproj` won't open (older Xcode) — 60-second manual setup
1. Xcode → **File → New → Project → iOS → App**. Name it `PingMe`, Interface **SwiftUI**, Language **Swift**. Save anywhere.
2. Delete the `ContentView.swift` it auto-created.
3. Drag these files from this `PingMe` source folder into the new project (tick *Copy items if needed* and the *PingMe* target): `PingMeApp.swift`, `ContentView.swift`, `AddReminderView.swift`, `Models.swift`, and the four `.wav` files. When asked, replace the existing `PingMeApp.swift`.
4. Drag in `Assets.xcassets` too (or just keep the default one and ignore the custom icon).
5. Build, then sign + export + sideload exactly as above.
