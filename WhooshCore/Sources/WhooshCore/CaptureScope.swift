import CoreGraphics
import Foundation

/// How much Whoosh looks at (§5.1). The founder chose both on 10 October 2026,
/// with This window as the default.
public enum CaptureScope: String, Codable, Sendable, CaseIterable {
    /// Only the window the user is working in.
    case window
    /// The whole display the user is working on, minus excluded apps, Whoosh,
    /// the system surfaces in `ScreenExclusions`, and the menu bar.
    case screen
}

/// Which apps a Whole screen capture removes from the picture. The window
/// server leaves their windows out of the image, so what lies behind shows
/// through instead.
public struct ScreenExclusions: Sendable, Equatable {
    /// System surfaces that can show private content, checked on macOS 15.7.
    public static let systemBundleIdentifiers: Set<String> = [
        "com.apple.notificationcenterui", // notification banners and Notification Center
        "com.apple.UserNotificationCenter", // older-style system alerts
        "com.apple.SecurityAgent", // system password prompts
        "com.apple.LocalAuthentication.UIAgent", // Touch ID prompts
        "com.apple.AutoFillPanelService", // password and contact autofill
        "com.apple.Passwords.MenuBarExtra", // the Passwords menu-bar panel
        "com.apple.AuthenticationServices.Helper", // sign-in and passkey sheets
    ]
    /// System surfaces that run without a bundle identifier, matched by process name.
    public static let systemProcessNames: Set<String> = ["AuthenticationServicesAgent"]

    private let bundleIdentifiers: Set<String>

    public init(list: ExclusionList, ownBundleIdentifier: String) {
        bundleIdentifiers = Set(
            (list.apps.map(\.bundleIdentifier) + [ownBundleIdentifier] + Self.systemBundleIdentifiers)
                .map { $0.lowercased() }
        )
    }

    public func excludes(bundleIdentifier: String, processName: String) -> Bool {
        bundleIdentifiers.contains(bundleIdentifier.lowercased()) || Self.systemProcessNames.contains(processName)
    }
}

/// Where the window in use sits inside a Whole screen capture, so the model
/// can tell what the user is working on.
public enum FocusRegion {
    /// - Parameters:
    ///   - window: The window in use, in global display coordinates (points, top-left origin).
    ///   - display: The captured display, in the same coordinates.
    ///   - croppedTop: Points removed from the top of the display, such as the menu bar.
    ///   - scale: Pixels per point in the captured image.
    /// - Returns: The visible part of the window in image pixels, or nil when none of it was captured.
    public static func pixels(window: CGRect, display: CGRect, croppedTop: CGFloat, scale: CGFloat) -> CGRect? {
        let captured = CGRect(
            x: display.minX,
            y: display.minY + croppedTop,
            width: display.width,
            height: display.height - croppedTop
        )
        let visible = window.intersection(captured)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return nil }
        return CGRect(
            x: (visible.minX - captured.minX) * scale,
            y: (visible.minY - captured.minY) * scale,
            width: visible.width * scale,
            height: visible.height * scale
        )
    }
}
