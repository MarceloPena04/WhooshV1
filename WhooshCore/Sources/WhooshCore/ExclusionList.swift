import Foundation

public struct ExcludedApp: Codable, Hashable, Sendable, Identifiable {
    public let bundleIdentifier: String
    /// Display name, used only in Whoosh's own interface; never logged (§8.2).
    public let name: String

    public init(bundleIdentifier: String, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    /// Bundle identifiers are case-insensitive, so matching uses this form.
    public var id: String { bundleIdentifier.lowercased() }
}

/// Apps Whoosh never captures, matched by bundle identifier (§5.1). Whoosh's
/// own windows are always skipped by `EligibilityPolicy`, whatever this list holds.
public struct ExclusionList: Codable, Equatable, Sendable {
    public private(set) var apps: [ExcludedApp]

    public init(apps: [ExcludedApp]) {
        self.apps = []
        for app in apps { add(app) }
    }

    /// The §5.1 defaults: password managers, Keychain Access, Passwords, and
    /// System Settings. The Apple identifiers were checked on macOS 15.7.
    public static let defaults = ExclusionList(apps: [
        ExcludedApp(bundleIdentifier: "com.apple.Passwords", name: "Passwords"),
        ExcludedApp(bundleIdentifier: "com.apple.keychainaccess", name: "Keychain Access"),
        ExcludedApp(bundleIdentifier: "com.apple.systempreferences", name: "System Settings"),
        ExcludedApp(bundleIdentifier: "com.1password.1password", name: "1Password"),
        ExcludedApp(bundleIdentifier: "com.agilebits.onepassword7", name: "1Password 7"),
        ExcludedApp(bundleIdentifier: "com.bitwarden.desktop", name: "Bitwarden"),
        ExcludedApp(bundleIdentifier: "org.keepassxc.keepassxc", name: "KeePassXC"),
    ])

    public func contains(_ bundleIdentifier: String) -> Bool {
        let id = bundleIdentifier.lowercased()
        return apps.contains { $0.id == id }
    }

    public mutating func add(_ app: ExcludedApp) {
        guard !contains(app.bundleIdentifier) else { return }
        apps.append(app)
    }

    public mutating func remove(_ bundleIdentifier: String) {
        let id = bundleIdentifier.lowercased()
        apps.removeAll { $0.id == id }
    }

    public init(from decoder: any Decoder) throws {
        self.init(apps: try decoder.singleValueContainer().decode([ExcludedApp].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apps)
    }
}
