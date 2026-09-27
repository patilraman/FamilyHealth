import SwiftUI

/// Account / app settings: shows the current api_id, allows editing the
/// credentials, and provides a logout action.
struct SettingsView: View {
    @EnvironmentObject private var session: TelegramSession
    @Environment(\.dismiss) private var dismiss

    @State private var apiId: String = ""
    @State private var apiHash: String = ""
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("api_id", text: $apiId)
                        .keyboardType(.numberPad)
                    TextField("api_hash", text: $apiHash)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Save credentials") { saveCredentials() }
                        .disabled(!isValid)
                } header: {
                    Text("Telegram credentials")
                } footer: {
                    Text("The api_hash is sensitive. Treat it like a password.")
                }

                Section {
                    if !session.statusMessage.isEmpty {
                        LabeledContentCompat("Connection", value: session.statusMessage)
                    }
                    LabeledContentCompat("Chats loaded", value: "\(session.chats.count)")
                } header: {
                    Text("Status")
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Text("Log out")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: prefill)
            .confirmationDialog(
                "Log out of Telegram?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log out", role: .destructive) {
                    session.logout()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to send messages.")
            }
        }
    }

    private var isValid: Bool {
        (Int(apiId) ?? 0) > 0 && !apiHash.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func prefill() {
        if let creds = session.currentCredentials {
            apiId = String(creds.apiId)
            apiHash = creds.apiHash
        }
    }

    private func saveCredentials() {
        guard let id = Int(apiId.trimmingCharacters(in: .whitespaces)) else { return }
        session.setCredentials(apiId: id, apiHash: apiHash.trimmingCharacters(in: .whitespaces))
    }
}

/// Backport of `LabeledContent` for iOS 15.
struct LabeledContentCompat: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TelegramSession())
}
