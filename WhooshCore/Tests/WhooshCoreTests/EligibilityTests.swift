import Foundation
import Testing
import WhooshCore

struct EligibilityTests {
    private let policy = EligibilityPolicy(ownBundleIdentifier: "com.olecramanep.Whoosh")
    private let editor = WindowIdentity(windowID: 7, bundleIdentifier: "com.example.Editor")

    private func input(
        isPaused: Bool = false,
        hasCapturePermission: Bool = true,
        isScreenLocked: Bool = false,
        isSecureInputActive: Bool = false,
        app: AppInUse = .app(bundleIdentifier: "com.example.Editor"),
        window: WindowIdentity? = WindowIdentity(windowID: 7, bundleIdentifier: "com.example.Editor")
    ) -> EligibilityInput {
        EligibilityInput(
            isPaused: isPaused,
            hasCapturePermission: hasCapturePermission,
            isScreenLocked: isScreenLocked,
            isSecureInputActive: isSecureInputActive,
            app: app,
            window: window
        )
    }

    @Test func eligibleWindowInUse() {
        #expect(policy.evaluate(input(), exclusions: .defaults) == .eligible(editor))
    }

    @Test func pausedWinsOverEverything() {
        let everythingWrong = input(isPaused: true, hasCapturePermission: false, isScreenLocked: true, isSecureInputActive: true, app: .none, window: nil)
        #expect(policy.evaluate(everythingWrong, exclusions: .defaults) == .skipped(.paused))
    }

    @Test func skipsWithoutPermissionOrWhileLocked() {
        #expect(policy.evaluate(input(hasCapturePermission: false), exclusions: .defaults) == .skipped(.permissionMissing))
        #expect(policy.evaluate(input(isScreenLocked: true), exclusions: .defaults) == .skipped(.screenLocked))
    }

    @Test func skipsExcludedAppsIgnoringCase() {
        let passwords = input(app: .app(bundleIdentifier: "COM.APPLE.PASSWORDS"), window: WindowIdentity(windowID: 3, bundleIdentifier: "COM.APPLE.PASSWORDS"))
        #expect(policy.evaluate(passwords, exclusions: .defaults) == .skipped(.excludedApp))
    }

    @Test func alwaysSkipsWhooshItselfEvenWithAnEmptyList() {
        let own = input(app: .app(bundleIdentifier: "com.olecramanep.Whoosh"), window: WindowIdentity(windowID: 9, bundleIdentifier: "com.olecramanep.Whoosh"))
        #expect(policy.evaluate(own, exclusions: ExclusionList(apps: [])) == .skipped(.ownApp))
    }

    @Test func skipsUnidentifiedAppsBecauseTheListCannotBeChecked() {
        #expect(policy.evaluate(input(app: .unidentified), exclusions: .defaults) == .skipped(.unidentifiedApp))
    }

    @Test func skipsDuringSecureInput() {
        #expect(policy.evaluate(input(isSecureInputActive: true), exclusions: .defaults) == .skipped(.secureInput))
    }

    @Test func skipsWhenNoWindowOrTheWindowBelongsToAnotherApp() {
        #expect(policy.evaluate(input(app: .none, window: nil), exclusions: .defaults) == .skipped(.noWindow))
        #expect(policy.evaluate(input(window: nil), exclusions: .defaults) == .skipped(.noWindow))
        let mismatched = input(window: WindowIdentity(windowID: 7, bundleIdentifier: "com.example.Other"))
        #expect(policy.evaluate(mismatched, exclusions: .defaults) == .skipped(.noWindow))
    }

    @Test func indicatorPriorities() {
        #expect(StatusIndicator(eligibility: .eligible(editor), isHushed: false) == .ready)
        #expect(StatusIndicator(eligibility: .eligible(editor), isHushed: true) == .hushed)
        #expect(StatusIndicator(eligibility: .skipped(.paused), isHushed: true) == .paused)
        #expect(StatusIndicator(eligibility: .skipped(.permissionMissing), isHushed: false) == .needsPermission)
        #expect(StatusIndicator(eligibility: .skipped(.excludedApp), isHushed: true) == .skipping(.excludedApp))
    }
}

struct ExclusionListTests {
    @Test func matchingIgnoresCaseAndAddingDeduplicates() {
        var list = ExclusionList(apps: [])
        list.add(ExcludedApp(bundleIdentifier: "com.example.Notes", name: "Notes"))
        list.add(ExcludedApp(bundleIdentifier: "COM.EXAMPLE.NOTES", name: "Notes again"))
        #expect(list.apps.count == 1)
        #expect(list.contains("com.Example.notes"))

        list.remove("COM.example.Notes")
        #expect(!list.contains("com.example.Notes"))
    }

    @Test func defaultsCoverPasswordsKeychainAndSettings() {
        for id in ["com.apple.Passwords", "com.apple.keychainaccess", "com.apple.systempreferences"] {
            #expect(ExclusionList.defaults.contains(id))
        }
    }

    @Test func encodesAsAPlainArray() throws {
        let list = ExclusionList(apps: [ExcludedApp(bundleIdentifier: "com.example.Notes", name: "Notes")])
        let data = try JSONEncoder().encode(list)
        #expect(try JSONSerialization.jsonObject(with: data) is [Any])
        #expect(try JSONDecoder().decode(ExclusionList.self, from: data) == list)
    }
}
