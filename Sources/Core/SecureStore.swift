import Foundation

/// Small credential store for the app: a JSON file in Application Support readable only by the user.
///
/// Not the Keychain on purpose: the app is signed with a self-made certificate, so macOS ties
/// Keychain items to each build's binary hash and asks for the login password after every update.
enum SecureStore {
    /// The local UI preview tool runs this code outside the app; it must never touch real data.
    private static let disabled = ProcessInfo.processInfo.environment["TERCANA_PREVIEW"] != nil

    private static var url: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tercana", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        return folder.appendingPathComponent("credentials.json")
    }

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return values
    }

    static func string(for key: String) -> String? {
        guard !disabled else { return nil }
        return load()[key]
    }

    static func set(_ value: String?, for key: String) {
        guard !disabled else { return }
        var values = load()
        values[key] = value
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
