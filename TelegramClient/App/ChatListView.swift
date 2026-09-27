import SwiftUI

/// Shows recent chats and lets the user open a conversation with another
/// Telegram user by @username or numeric user id. Selecting a chat pushes
/// `ChatView`.
struct ChatListView: View {
    @EnvironmentObject private var session: TelegramSession

    @State private var showNewChat = false
    @State private var showSettings = false
    @State private var navigateToOpenChat = false

    var body: some View {
        NavigationStack {
            List {
                if session.chats.isEmpty {
                    ContentUnavailableCompat(
                        title: "No chats yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: "Tap the compose button to start a conversation with another Telegram user."
                    )
                } else {
                    ForEach(session.chats) { chat in
                        Button {
                            session.openExistingChat(chatId: chat.id)
                            navigateToOpenChat = true
                        } label: {
                            ChatRow(chat: chat)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(isPresented: $navigateToOpenChat) {
                ChatView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatSheet { navigateToOpenChat = true }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .refreshable {
                session.loadRecentChats()
            }
            .overlay(alignment: .bottom) {
                if !session.statusMessage.isEmpty && session.statusMessage != "Connected" {
                    Text(session.statusMessage)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct ChatRow: View {
    let chat: ChatSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(Text(initials).font(.headline).foregroundStyle(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title.isEmpty ? "Chat \(chat.id)" : chat.title)
                    .font(.body)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var initials: String {
        let parts = chat.title.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

/// Sheet to start a new conversation. Accepts a @username or a numeric user id.
private struct NewChatSheet: View {
    @EnvironmentObject private var session: TelegramSession
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    var onOpened: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("@username or user id", text: $query)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Enter the other user's public @username, or their numeric Telegram user id.")
                }

                Section {
                    Button("Open chat") { open() }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func open() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if let userId = Int64(trimmed) {
            session.openChat(withUserId: userId)
        } else {
            session.openChat(withUsername: trimmed)
        }
        dismiss()
        onOpened()
    }
}

/// Backport of `ContentUnavailableView` so this compiles on iOS 15/16 too.
struct ContentUnavailableCompat: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    ChatListView()
        .environmentObject(TelegramSession())
}
