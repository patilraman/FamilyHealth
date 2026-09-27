import SwiftUI

/// The conversation screen: a scrollable list of message bubbles plus a
/// composer bar for sending text to the other user.
struct ChatView: View {
    @EnvironmentObject private var session: TelegramSession
    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            composer
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        if let id = session.openChatId,
           let chat = session.chats.first(where: { $0.id == id }),
           !chat.title.isEmpty {
            return chat.title
        }
        return "Chat"
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(session.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: session.messages.count) { _ in
                if let last = session.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = session.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func send() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        session.sendText(text)
        draft = ""
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 40) }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundStyle(message.isOutgoing ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isOutgoing { Spacer(minLength: 40) }
        }
    }

    private var bubbleColor: Color {
        message.isOutgoing ? Color.accentColor : Color(.secondarySystemBackground)
    }
}

#Preview {
    NavigationStack {
        ChatView()
            .environmentObject(TelegramSession())
    }
}
