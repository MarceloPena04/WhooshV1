import AppKit
import CoreGraphics

/// The Screen Recording permission (§5.1). macOS grants it for the whole
/// screen; Whoosh's own rules narrow it to the window in use.
enum ScreenRecordingPermission {
    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows macOS's prompt. macOS shows it only once; after that, the
    /// permission can only be changed in System Settings.
    static func request() {
        CGRequestScreenCaptureAccess()
    }

    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}
