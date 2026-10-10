import Foundation
import Testing
import WhooshCore

struct SettingsStoreTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "WhooshCoreTests-\(UUID().uuidString)")

    private var store: SettingsStore {
        SettingsStore(fileURL: directory.appending(path: "Whoosh/settings.json"))
    }

    @Test func missingFileYieldsDefaults() throws {
        #expect(try store.load() == AppSettings())
    }

    @Test func roundTrips() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        var settings = AppSettings()
        settings.onboardingCompleted = true
        settings.exclusions.add(ExcludedApp(bundleIdentifier: "com.example.Notes", name: "Notes"))

        try store.save(settings)
        #expect(try store.load() == settings)
    }

    @Test func unreadableFileThrowsAndIsLeftUntouched() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let corrupt = Data("{ not json".utf8)
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try corrupt.write(to: store.fileURL)

        #expect(throws: SettingsError.unreadable) { try store.load() }
        #expect(try Data(contentsOf: store.fileURL) == corrupt)
    }

    @Test func rejectsOtherSchemaVersions() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 2}"#.utf8).write(to: store.fileURL)

        #expect(throws: SettingsError.unsupportedVersion) { try store.load() }
    }

    @Test func missingKeysTakeDefaults() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 1, "onboardingCompleted": true}"#.utf8).write(to: store.fileURL)

        let settings = try store.load()
        #expect(settings.onboardingCompleted)
        #expect(settings.exclusions == .defaults)
    }
}
