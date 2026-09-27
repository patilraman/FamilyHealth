import Foundation

/// Telegram application credentials.
///
/// You obtain `apiId` and `apiHash` by registering an application at
/// https://my.telegram.org  ->  "API development tools".
///
/// These are stored in `UserDefaults` for convenience in this sample.
/// In a production app you should keep the `apiHash` in the Keychain.
struct Credentials: Codable, Equatable {
    var apiId: Int
    var apiHash: String

    var isValid: Bool {
        apiId > 0 && !apiHash.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

enum CredentialsStore {
    private static let key = "telegram.credentials"

    static func load() -> Credentials? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    static func save(_ credentials: Credentials) {
        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
