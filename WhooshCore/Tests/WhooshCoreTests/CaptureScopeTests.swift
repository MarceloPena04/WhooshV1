import CoreGraphics
import Foundation
import Testing
import WhooshCore

struct ScreenExclusionsTests {
    private let exclusions = ScreenExclusions(
        list: ExclusionList(apps: [ExcludedApp(bundleIdentifier: "com.example.Chat", name: "Chat")]),
        ownBundleIdentifier: "com.olecramanep.Whoosh"
    )

    @Test func removesListedAppsWhooshAndSystemSurfaces() {
        #expect(exclusions.excludes(bundleIdentifier: "COM.EXAMPLE.CHAT", processName: "Chat"))
        #expect(exclusions.excludes(bundleIdentifier: "com.olecramanep.Whoosh", processName: "Whoosh"))
        #expect(exclusions.excludes(bundleIdentifier: "com.apple.notificationcenterui", processName: "NotificationCenter"))
        #expect(exclusions.excludes(bundleIdentifier: "com.apple.SecurityAgent", processName: "SecurityAgent"))
        #expect(exclusions.excludes(bundleIdentifier: "", processName: "AuthenticationServicesAgent"))
    }

    @Test func keepsEverythingElse() {
        #expect(!exclusions.excludes(bundleIdentifier: "com.apple.Safari", processName: "Safari"))
        #expect(!exclusions.excludes(bundleIdentifier: "", processName: "SomeTool"))
    }
}

struct FocusRegionTests {
    // The Sidecar display from the M0 test machine: 1366 x 1024 points to the
    // right of the 1512-point built-in display, with a 24-point menu bar.
    private let sidecar = CGRect(x: 1512, y: 0, width: 1366, height: 1024)

    @Test func convertsTheWindowToPixelsBelowTheCroppedMenuBar() {
        let window = CGRect(x: 1512, y: 24, width: 1366, height: 1000)
        let region = FocusRegion.pixels(window: window, display: sidecar, croppedTop: 24, scale: 2)
        #expect(region == CGRect(x: 0, y: 0, width: 2732, height: 2000))
    }

    @Test func clipsWindowsThatHangOffTheDisplay() {
        let window = CGRect(x: 1412, y: 100, width: 300, height: 200)
        let region = FocusRegion.pixels(window: window, display: sidecar, croppedTop: 24, scale: 2)
        #expect(region == CGRect(x: 0, y: 152, width: 400, height: 400))
    }

    @Test func windowOnAnotherDisplayHasNoRegion() {
        let window = CGRect(x: 100, y: 100, width: 300, height: 200)
        #expect(FocusRegion.pixels(window: window, display: sidecar, croppedTop: 24, scale: 2) == nil)
    }
}
