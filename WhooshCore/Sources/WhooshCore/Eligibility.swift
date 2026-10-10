import Foundation

/// The app the user is working in, as far as the platform layer can tell.
public enum AppInUse: Sendable, Equatable {
    case none
    /// An app without a bundle identifier, which the exclusion list cannot match.
    case unidentified
    case app(bundleIdentifier: String)
}

/// What the platform layer observed just before a capture decision (§5.1).
public struct EligibilityInput: Sendable, Equatable {
    public var isPaused: Bool
    public var hasCapturePermission: Bool
    public var isScreenLocked: Bool
    public var isSecureInputActive: Bool
    public var app: AppInUse
    /// The app's frontmost normal on-screen window, when one was found.
    public var window: WindowIdentity?

    public init(
        isPaused: Bool,
        hasCapturePermission: Bool,
        isScreenLocked: Bool,
        isSecureInputActive: Bool,
        app: AppInUse,
        window: WindowIdentity?
    ) {
        self.isPaused = isPaused
        self.hasCapturePermission = hasCapturePermission
        self.isScreenLocked = isScreenLocked
        self.isSecureInputActive = isSecureInputActive
        self.app = app
        self.window = window
    }
}

/// Why Whoosh is not looking at the window in use. Content-free, so it can be logged.
public enum SkipReason: String, Sendable, Equatable {
    case paused
    case permissionMissing
    case screenLocked
    case unidentifiedApp
    case ownApp
    case excludedApp
    case secureInput
    case noWindow
}

public enum Eligibility: Sendable, Equatable {
    case eligible(WindowIdentity)
    case skipped(SkipReason)
}

/// Decides whether the window in use may be captured (§5.1). Anything the
/// policy cannot positively establish is skipped; it never widens the capture.
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
        if bundleIdentifier.lowercased() == ownBundleIdentifier.lowercased() { return .skipped(.ownApp) }
        if exclusions.contains(bundleIdentifier) { return .skipped(.excludedApp) }
        if input.isSecureInputActive { return .skipped(.secureInput) }

        guard let window = input.window,
              window.bundleIdentifier.lowercased() == bundleIdentifier.lowercased()
        else { return .skipped(.noWindow) }
        return .eligible(window)
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
