# TelegramClient (iOS)

A minimal SwiftUI iPhone app that talks to Telegram through **TDLib**, using the
[TDLibKit](https://github.com/Swiftgram/TDLibKit) Swift package. It signs in with
your own `api_id` / `api_hash` and lets you message another Telegram user.

## What it does

- Signs in with the full TDLib auth flow: credentials → phone number → login code
  → (optional 2FA password) → (optional registration for new accounts).
- Loads your recent chats.
- Starts a conversation with another user by public `@username` or numeric user id.
- Sends and receives text messages in real time, with sent/received bubbles.

## Requirements

- Xcode 15 or newer
- iOS 16.0+ device or simulator
- A Telegram `api_id` and `api_hash`

> TDLibKit depends on
> [TDLibFramework](https://github.com/Swiftgram/TDLibFramework), which downloads a
> large (~300 MB) prebuilt XCFramework the first time packages are resolved. The
> first build will take a while.

## Getting your api_id / api_hash

1. Go to <https://my.telegram.org> and log in with your phone number.
2. Open **API development tools**.
3. Create a new application. Any title / short name works for personal use.
4. Copy the **api_id** (a number) and **api_hash** (a hex string).

You enter these on the first screen of the app. They're stored in `UserDefaults`
for convenience in this sample — for production, move the `api_hash` to the
Keychain.

## Opening the project

1. Open `TelegramClient.xcodeproj` in Xcode.
2. Xcode resolves the TDLibKit Swift package automatically. If it doesn't, use
   **File → Packages → Resolve Package Versions**. The pinned URL is
   `https://github.com/Swiftgram/TDLibKit`.
3. Select the **TelegramClient** scheme and an iPhone simulator (or your device).
4. Set your own signing team under **Signing & Capabilities** if you run on a
   physical device.
5. Build and run.

## Using the app

1. Enter your `api_id` and `api_hash`, tap **Continue**.
2. Enter your phone number in international format (e.g. `+1 555 123 4567`).
3. Enter the login code Telegram sends you.
4. If you have two-step verification, enter your password.
5. On the **Chats** screen tap the compose button (top right) and enter the other
   user's `@username` or numeric id to open a conversation.
6. Type in the composer and tap send.

Pull to refresh the chat list. Use the gear icon (top left) to review credentials
or log out.

## Project layout

```
TelegramClient/
├─ TelegramClient.xcodeproj      # Xcode project (references the TDLibKit SPM package)
├─ README.md
└─ App/
   ├─ TelegramClientApp.swift    # @main entry point, owns the TelegramSession
   ├─ TelegramSession.swift      # TDLib client, auth state machine, messaging
   ├─ Credentials.swift          # api_id / api_hash model + storage
   ├─ RootView.swift             # routes between auth and chats based on state
   ├─ AuthView.swift             # multi-step sign-in form
   ├─ ChatListView.swift         # recent chats + "new chat" sheet
   ├─ ChatView.swift             # message bubbles + composer
   ├─ SettingsView.swift         # edit credentials, log out
   ├─ Assets.xcassets            # app icon + accent color
   └─ Info.plist
```

## Notes & limitations

- This is a focused sample: text messages only (incoming photos/videos/etc. are
  shown as placeholders like `[Photo]`).
- Secret chats are disabled in the TDLib parameters.
- The TDLib database is stored under the app's Documents directory
  (`tdlib/`, with downloaded files under `tdlib/files/`).
- Do not commit your `api_hash` to source control.
