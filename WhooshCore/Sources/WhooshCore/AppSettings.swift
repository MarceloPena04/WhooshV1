import Foundation

/// Settings kept in local JSON (§4.1). No screen content, titles, or message
/// text belongs here; credentials live in the Keychain (§8.1).
public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion = AppSettings.currentSchemaVersion
    public var onboardingCompleted = false
    /// Whether Whoosh has shown macOS's Screen Recording prompt. macOS shows it
    /// only once, so later requests open System Settings instead.
    public var screenRecordingRequested = false
    public var exclusions = ExclusionList.defaults
    public var captureScope = CaptureScope.window

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case onboardingCompleted
        case screenRecordingRequested
        case exclusions
        case captureScope
    }

    /// Missing keys take their defaults, so adding a setting does not make older files unreadable.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        screenRecordingRequested = try container.decodeIfPresent(Bool.self, forKey: .screenRecordingRequested) ?? false
        exclusions = try container.decodeIfPresent(ExclusionList.self, forKey: .exclusions) ?? .defaults
        captureScope = try container.decodeIfPresent(CaptureScope.self, forKey: .captureScope) ?? .window
    }
}

public enum SettingsError: Error, Sendable, Equatable {
    case unreadable
    case unsupportedVersion
    case writeFailed
}

public struct SettingsStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// A missing file yields the defaults. A file that exists but cannot be
    /// read throws, and the caller must leave it untouched rather than
    /// silently resetting it (§9).
    public func load() throws(SettingsError) -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return AppSettings() }
        let settings: AppSettings
        do {
            settings = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: fileURL))
        } catch {
            throw .unreadable
        }
        guard settings.schemaVersion == AppSettings.currentSchemaVersion else { throw .unsupportedVersion }
        return settings
    }

    /// Writes atomically, so a crash leaves either the old or the new file.
    public func save(_ settings: AppSettings) throws(SettingsError) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(settings).write(to: fileURL, options: .atomic)
        } catch {
            throw .writeFailed
        }
    }
}
