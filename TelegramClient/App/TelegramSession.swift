import Foundation
import Combine
import TDLibKit

/// High-level authorization state exposed to the UI.
enum AuthState: Equatable {
    case initializing
    case waitingForCredentials          // no api_id / api_hash yet
    case waitingForPhoneNumber
    case waitingForCode
    case waitingForPassword             // 2FA password
    case waitingForRegistration         // new account, needs first/last name
    case ready                          // fully logged in
    case loggingOut
    case closed
}

/// Owns the single `TDLibClientManager` / client and drives the whole
/// authentication flow plus messaging with one other Telegram user.
@MainActor
final class TelegramSession: ObservableObject {

    // MARK: Published UI state

    @Published private(set) var authState: AuthState = .initializing
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var chats: [ChatSummary] = []
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var openChatId: Int64?
    @Published var lastError: String?

    // MARK: TDLib plumbing

    private let manager = TDLibClientManager()
    private var client: TDLibClient?

    /// Credentials must be set before authentication can complete.
    private var credentials: Credentials?

    init() {
        self.credentials = CredentialsStore.load()
        start()
    }

    // MARK: - Lifecycle

    func start() {
        // Reduce noise from TDLib's own logging.
        setLogVerbosity(1)

        client = manager.createClient(updateHandler: { [weak self] data, client in
            guard let self else { return }
            do {
                let update = try client.decoder.decode(Update.self, from: data)
                Task { @MainActor in
                    self.handle(update: update)
                }
            } catch {
                // Non-fatal: many updates are not modeled/needed here.
            }
        })
    }

    func shutdown() {
        authState = .closed
        manager.closeClients()
    }

    // MARK: - Credentials

    var hasCredentials: Bool { credentials?.isValid ?? false }

    var currentCredentials: Credentials? { credentials }

    func setCredentials(apiId: Int, apiHash: String) {
        let creds = Credentials(apiId: apiId, apiHash: apiHash)
        guard creds.isValid else {
            lastError = "api_id and api_hash are required."
            return
        }
        credentials = creds
        CredentialsStore.save(creds)
        // If TDLib is already waiting for parameters, send them now.
        Task { await sendTdlibParametersIfNeeded() }
    }

    // MARK: - Auth actions (called from the UI)

    func submitPhoneNumber(_ phone: String) {
        let cleaned = phone.trimmingCharacters(in: .whitespaces)
        run { client in
            _ = try await client.setAuthenticationPhoneNumber(
                phoneNumber: cleaned,
                settings: nil
            )
        }
    }

    func submitCode(_ code: String) {
        let cleaned = code.trimmingCharacters(in: .whitespaces)
        run { client in
            _ = try await client.checkAuthenticationCode(code: cleaned)
        }
    }

    func submitPassword(_ password: String) {
        run { client in
            _ = try await client.checkAuthenticationPassword(password: password)
        }
    }

    func submitRegistration(firstName: String, lastName: String) {
        run { client in
            _ = try await client.registerUser(
                disableNotification: false,
                firstName: firstName,
                lastName: lastName
            )
        }
    }

    func logout() {
        authState = .loggingOut
        run { client in
            _ = try await client.logOut()
        }
    }

    // MARK: - Messaging

    /// Resolve a user by @username or phone number and open a private chat.
    func openChat(withUsername username: String) {
        let name = username.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "@", with: "")
        Task {
            do {
                guard let client else { return }
                let chat = try await client.searchPublicChat(username: name)
                await loadChat(chat.id)
            } catch {
                await MainActor.run { self.lastError = "Could not find user '\(username)': \(error.localizedDescription)" }
            }
        }
    }

    /// Open a private chat by numeric Telegram user id.
    func openChat(withUserId userId: Int64) {
        Task {
            do {
                guard let client else { return }
                let chat = try await client.createPrivateChat(force: false, userId: userId)
                await loadChat(chat.id)
            } catch {
                await MainActor.run { self.lastError = "Could not open chat: \(error.localizedDescription)" }
            }
        }
    }

    /// Open an already-known chat by its chat id (e.g. a row tapped in the
    /// chat list). Unlike `openChat(withUserId:)`, this does not create a new
    /// private chat — it just loads the existing conversation.
    func openExistingChat(chatId: Int64) {
        Task { await loadChat(chatId) }
    }

    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let chatId = openChatId, let client else { return }
        let content = InputMessageContent.inputMessageText(
            InputMessageText(
                clearDraft: true,
                linkPreviewOptions: nil,
                text: FormattedText(entities: [], text: trimmed)
            )
        )
        Task {
            _ = try? await client.sendMessage(
                chatId: chatId,
                inputMessageContent: content,
                options: nil,
                replyMarkup: nil,
                replyTo: nil,
                topicId: nil
            )
        }
    }

    func loadRecentChats() {
        Task {
            guard let client else { return }
            _ = try? await client.loadChats(chatList: .chatListMain, limit: 30)
        }
    }

    // MARK: - Update handling

    private func handle(update: Update) {
        switch update {
        case .updateAuthorizationState(let state):
            handleAuthorizationState(state.authorizationState)

        case .updateNewMessage(let payload):
            appendIfForOpenChat(payload.message)

        case .updateNewChat(let payload):
            upsertChat(payload.chat)

        case .updateConnectionState(let payload):
            statusMessage = describe(payload.state)

        default:
            break
        }
    }

    private func handleAuthorizationState(_ state: AuthorizationState) {
        switch state {
        case .authorizationStateWaitTdlibParameters:
            Task { await sendTdlibParametersIfNeeded() }

        case .authorizationStateWaitPhoneNumber:
            authState = .waitingForPhoneNumber

        case .authorizationStateWaitCode:
            authState = .waitingForCode

        case .authorizationStateWaitPassword:
            authState = .waitingForPassword

        case .authorizationStateWaitRegistration:
            authState = .waitingForRegistration

        case .authorizationStateReady:
            authState = .ready
            loadRecentChats()

        case .authorizationStateLoggingOut:
            authState = .loggingOut

        case .authorizationStateClosing:
            statusMessage = "Closing…"

        case .authorizationStateClosed:
            authState = .closed

        default:
            break
        }
    }

    /// Sends `SetTdlibParameters` using the stored credentials, if present.
    private func sendTdlibParametersIfNeeded() async {
        guard let creds = credentials, creds.isValid else {
            authState = .waitingForCredentials
            return
        }
        guard let client else { return }

        let dir = documentsSubdirectory("tdlib")
        let params = SetTdlibParameters(
            apiHash: creds.apiHash,
            apiId: creds.apiId,
            applicationVersion: "1.0",
            databaseDirectory: dir.path,
            databaseEncryptionKey: Data(),
            deviceModel: "iPhone",
            filesDirectory: dir.appendingPathComponent("files").path,
            systemLanguageCode: "en",
            systemVersion: "iOS",
            useChatInfoDatabase: true,
            useFileDatabase: true,
            useMessageDatabase: true,
            useSecretChats: false,
            useTestDc: false
        )
        do {
            _ = try await client.setTdlibParameters(
                apiHash: params.apiHash,
                apiId: params.apiId,
                applicationVersion: params.applicationVersion,
                databaseDirectory: params.databaseDirectory,
                databaseEncryptionKey: params.databaseEncryptionKey,
                deviceModel: params.deviceModel,
                filesDirectory: params.filesDirectory,
                systemLanguageCode: params.systemLanguageCode,
                systemVersion: params.systemVersion,
                useChatInfoDatabase: params.useChatInfoDatabase,
                useFileDatabase: params.useFileDatabase,
                useMessageDatabase: params.useMessageDatabase,
                useSecretChats: params.useSecretChats,
                useTestDc: params.useTestDc
            )
        } catch {
            lastError = "Failed to initialize TDLib: \(error.localizedDescription)"
        }
    }

    // MARK: - Chat/message helpers

    private func loadChat(_ chatId: Int64) async {
        openChatId = chatId
        messages = []
        guard let client else { return }
        _ = try? await client.openChat(chatId: chatId)
        do {
            let history = try await client.getChatHistory(
                chatId: chatId,
                fromMessageId: 0,
                limit: 50,
                offset: 0,
                onlyLocal: false
            )
            //let mapped = history.messages.reversed().map(ChatMessage.init(message:))
            let mapped = (history.messages ?? []).reversed().map(ChatMessage.init(message:))

            await MainActor.run { self.messages = mapped }
        } catch {
            await MainActor.run { self.lastError = "Failed to load history: \(error.localizedDescription)" }
        }
    }

    private func appendIfForOpenChat(_ message: Message) {
        guard message.chatId == openChatId else { return }
        messages.append(ChatMessage(message: message))
    }

    private func upsertChat(_ chat: Chat) {
        let summary = ChatSummary(id: chat.id, title: chat.title)
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx] = summary
        } else {
            chats.append(summary)
        }
    }

    // MARK: - Low-level send

    /// Runs a typed TDLib request using the async API, routing any thrown
    /// error to `lastError` on the main actor.
    private func run(_ body: @escaping (TDLibClient) async throws -> Void) {
        guard let client else { return }
        Task {
            do {
                try await body(client)
            } catch {
                await MainActor.run { self.lastError = error.localizedDescription }
            }
        }
    }

    /// Sets TDLib's log verbosity. This is one of the few requests that can be
    /// executed synchronously, so it uses `execute(query:)` with a `DTO` wrap.
    private func setLogVerbosity(_ level: Int) {
        _ = try? client?.execute(query: DTO(SetLogVerbosityLevel(newVerbosityLevel: level)))
    }

    private func describe(_ state: ConnectionState) -> String {
        switch state {
        case .connectionStateConnecting: return "Connecting…"
        case .connectionStateConnectingToProxy: return "Connecting to proxy…"
        case .connectionStateUpdating: return "Updating…"
        case .connectionStateReady: return "Connected"
        case .connectionStateWaitingForNetwork: return "Waiting for network…"
        }
    }

    private func documentsSubdirectory(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - Lightweight view models

struct ChatSummary: Identifiable, Equatable {
    let id: Int64
    let title: String
}

struct ChatMessage: Identifiable, Equatable {
    let id: Int64
    let text: String
    let isOutgoing: Bool
    let date: Foundation.Date

    init(message: Message) {
        self.id = message.id
        self.isOutgoing = message.isOutgoing
        self.date = Date(timeIntervalSince1970: TimeInterval(message.date))
        switch message.content {
        case .messageText(let t):
            self.text = t.text.text
        case .messagePhoto(let p):
            self.text = p.caption.text.isEmpty ? "[Photo]" : "📷 \(p.caption.text)"
        case .messageVideo(let v):
            self.text = v.caption.text.isEmpty ? "[Video]" : "🎬 \(v.caption.text)"
        case .messageSticker(let s):
            self.text = s.sticker.emoji
        case .messageAnimation:
            self.text = "[GIF]"
        case .messageDocument(let d):
            self.text = "📎 \(d.document.fileName)"
        default:
            self.text = "[Unsupported message]"
        }
    }
}
