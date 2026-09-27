import SwiftUI

/// Top-level router. Chooses the screen based on the session's auth state and
/// surfaces any error via an alert.
struct RootView: View {
    @EnvironmentObject private var session: TelegramSession

    var body: some View {
        Group {
            switch session.authState {
            case .initializing:
                LoadingView(message: "Starting…")

            case .waitingForCredentials,
                 .waitingForPhoneNumber,
                 .waitingForCode,
                 .waitingForPassword,
                 .waitingForRegistration:
                AuthView()

            case .ready:
                ChatListView()

            case .loggingOut:
                LoadingView(message: "Logging out…")

            case .closed:
                LoadingView(message: "Session closed.")
            }
        }
        .animation(.default, value: session.authState)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { session.lastError != nil },
                set: { if !$0 { session.lastError = nil } }
            ),
            presenting: session.lastError
        ) { _ in
            Button("OK", role: .cancel) { session.lastError = nil }
        } message: { error in
            Text(error)
        }
    }
}

/// Simple centered spinner with a caption.
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    RootView()
        .environmentObject(TelegramSession())
}
