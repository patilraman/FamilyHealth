import SwiftUI

@main
struct TelegramClientApp: App {
    // The shared TDLib manager lives for the whole app lifecycle.
    @StateObject private var session = TelegramSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .onDisappear {
                    session.shutdown()
                }
        }
    }
}
