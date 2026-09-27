import SwiftUI

/// Drives the full sign-in flow: credentials → phone → code → (password) →
/// (registration). Which fields appear is decided by `session.authState`.
struct AuthView: View {
    @EnvironmentObject private var session: TelegramSession

    var body: some View {
        NavigationStack {
            Form {
                switch session.authState {
                case .waitingForCredentials:
                    CredentialsSection()
                case .waitingForPhoneNumber:
                    PhoneSection()
                case .waitingForCode:
                    CodeSection()
                case .waitingForPassword:
                    PasswordSection()
                case .waitingForRegistration:
                    RegistrationSection()
                default:
                    EmptyView()
                }

                if !session.statusMessage.isEmpty {
                    Section {
                        Label(session.statusMessage, systemImage: "wifi")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Sign in to Telegram")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Step 1: API credentials

private struct CredentialsSection: View {
    @EnvironmentObject private var session: TelegramSession
    @State private var apiId: String = ""
    @State private var apiHash: String = ""

    var body: some View {
        Section {
            TextField("api_id (numbers)", text: $apiId)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
            TextField("api_hash", text: $apiHash)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } header: {
            Text("Telegram application credentials")
        } footer: {
            Text("Create an application at my.telegram.org → API development tools to obtain your api_id and api_hash.")
        }

        Section {
            Button("Continue") { submit() }
                .disabled(!isValid)
        }
        .onAppear(perform: prefill)
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

    private func submit() {
        guard let id = Int(apiId.trimmingCharacters(in: .whitespaces)) else { return }
        session.setCredentials(apiId: id, apiHash: apiHash.trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Step 2: Phone number

private struct PhoneSection: View {
    @EnvironmentObject private var session: TelegramSession
    @State private var phone: String = ""

    var body: some View {
        Section {
            TextField("+1 555 123 4567", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
        } header: {
            Text("Phone number")
        } footer: {
            Text("Enter your number in international format, including the country code.")
        }

        Section {
            Button("Send code") { session.submitPhoneNumber(phone) }
                .disabled(phone.trimmingCharacters(in: .whitespaces).count < 5)
        }
    }
}

// MARK: - Step 3: Login code

private struct CodeSection: View {
    @EnvironmentObject private var session: TelegramSession
    @State private var code: String = ""

    var body: some View {
        Section {
            TextField("12345", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
        } header: {
            Text("Confirmation code")
        } footer: {
            Text("Telegram sent a code to your other logged-in devices or via SMS.")
        }

        Section {
            Button("Verify") { session.submitCode(code) }
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// MARK: - Step 4: 2FA password

private struct PasswordSection: View {
    @EnvironmentObject private var session: TelegramSession
    @State private var password: String = ""

    var body: some View {
        Section {
            SecureField("Password", text: $password)
                .textContentType(.password)
        } header: {
            Text("Two-step verification")
        } footer: {
            Text("Your account is protected with a password. Enter it to continue.")
        }

        Section {
            Button("Continue") { session.submitPassword(password) }
                .disabled(password.isEmpty)
        }
    }
}

// MARK: - Step 5: Registration (new account)

private struct RegistrationSection: View {
    @EnvironmentObject private var session: TelegramSession
    @State private var firstName: String = ""
    @State private var lastName: String = ""

    var body: some View {
        Section {
            TextField("First name", text: $firstName)
                .textContentType(.givenName)
            TextField("Last name (optional)", text: $lastName)
                .textContentType(.familyName)
        } header: {
            Text("Create your account")
        }

        Section {
            Button("Create account") {
                session.submitRegistration(firstName: firstName, lastName: lastName)
            }
            .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(TelegramSession())
}
