import Foundation

/// The app the user is working in, as far as the platform layer can tell.
public enum AppInUse: Sendable, Equatable {
    case none
    /// An app without a bundle identifier, which the exclusion list cannot match.
    case unidentified
    case app(bundleIdentifier: String)
}

/// A Whole screen capture: one display, and the window in use on it, if any.
public struct DisplayTarget: Sendable, Hashable {
    public let displayID: UInt32
    public let appBundleIdentifier: String
    /// Nil when the desktop is in front.
    public let focusWindow: WindowIdentity?

    public init(displayID: UInt32, appBundleIdentifier: String, focusWindow: WindowIdentity?) {
        self.displayID = displayID
        self.appBundleIdentifier = appBundleIdentifier
        self.focusWindow = focusWindow
    }
}

/// What a capture may contain, depending on the capture scope.
public enum CaptureTarget: Sendable, Hashable {
    case window(WindowIdentity)
    case display(DisplayTarget)
}

/// What the platform layer observed just before a capture decision (§5.1).
public struct EligibilityInput: Sendable, Equatable {
    public var scope: CaptureScope
    public var isPaused: Bool
    public var hasCapturePermission: Bool
    public var isScreenLocked: Bool
    public var isSecureInputActive: Bool
    public var app: AppInUse
    /// The app's frontmost normal on-screen window, when one was found.
    public var window: WindowIdentity?
    /// The display holding that window, or the display under the pointer when there is none.
    public var displayID: UInt32?

    public init(
        scope: CaptureScope = .window,
        isPaused: Bool,
        hasCapturePermission: Bool,
        isScreenLocked: Bool,
        isSecureInputActive: Bool,
        app: AppInUse,
        window: WindowIdentity?,
        displayID: UInt32? = nil
    ) {
        self.scope = scope
        self.isPaused = isPaused
        self.hasCapturePermission = hasCapturePermission
        self.isScreenLocked = isScreenLocked
        self.isSecureInputActive = isSecureInputActive
        self.app = app
        self.window = window
        self.displayID = displayID
    }
}

/// Why Whoosh is not looking. Content-free, so it can be logged.
public enum SkipReason: String, Sendable, Equatable {
    case paused
    case permissionMissing
    case screenLocked
    case unidentifiedApp
    case ownApp
    case excludedApp
    case secureInput
    case noWindow
    case noDisplay
}

public enum Eligibility: Sendable, Equatable {
    case eligible(CaptureTarget)
    case skipped(SkipReason)
}

/// Decides whether Whoosh may capture, and what (§5.1). Anything the policy
/// cannot positively establish is skipped; it never widens the capture.
public struct EligibilityPolicy: Sendable {
    public let ownBundleIdentifier: String

    public init(ownBundleIdentifier: String) {
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    public func evaluate(_ input: EligibilityInput, exclusions: ExclusionList) -> Eligibility {
        if input.isPaused { return .skipped(.paused) }
        if !input.hasCapturePermission { return .skipped(.permissionMissing) }
        if input.isScreenLocked { return .skipped(.screenLocked) }

        let bundleIdentifier: String
        switch input.app {
        case .none: return .skipped(.noWindow)
        case .unidentified: return .skipped(.unidentifiedApp)
        case .app(let identifier): bundleIdentifier = identifier
        }
        // An excluded app in use stops the capture in both scopes: Whole
        // screen does not capture everything around it instead.
        if bundleIdentifier.lowercased() == ownBundleIdentifier.lowercased() { return .skipped(.ownApp) }
        if exclusions.contains(bundleIdentifier) { return .skipped(.excludedApp) }
        if input.isSecureInputActive { return .skipped(.secureInput) }

        let window = input.window.flatMap {
            $0.bundleIdentifier.lowercased() == bundleIdentifier.lowercased() ? $0 : nil
        }
        switch input.scope {
        case .window:
            guard let window else { return .skipped(.noWindow) }
            return .eligible(.window(window))
        case .screen:
            guard let displayID = input.displayID else { return .skipped(.noDisplay) }
            return .eligible(.display(DisplayTarget(displayID: displayID, appBundleIdentifier: bundleIdentifier, focusWindow: window)))
        }
    }
}

/// What the menu-bar icon shows (§2.1): watching, paused, hushed, or skipping.
public enum StatusIndicator: Sendable, Equatable {
    case ready
    case paused
    case hushed
    case needsPermission
    case skipping(SkipReason)

    /// Paused wins, then anything that stops capture, then Hush: skipping an
    /// excluded app matters more to show than being quiet.
    public init(eligibility: Eligibility, isHushed: Bool) {
        switch eligibility {
        case .skipped(.paused): self = .paused
        case .skipped(.permissionMissing): self = .needsPermission
        case .skipped(let reason): self = .skipping(reason)
        case .eligible: self = isHushed ? .hushed : .ready
        }
    }
}
