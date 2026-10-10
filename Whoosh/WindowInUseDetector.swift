import AppKit
import Carbon.HIToolbox
import WhooshCore

/// What the detector saw at one moment. Names are for Whoosh's own interface only.
struct WindowObservation {
    var app: AppInUse = .none
    var appName: String?
    var bundleIdentifier: String?
    var processID: pid_t?
    var window: WindowIdentity?
    /// The window's frame in global display coordinates (origin at the top left of the main display).
    var windowFrame: CGRect?
    var isScreenLocked = false
    var isSecureInputActive = false
}

/// Finds the window the user is working in (§5.1) using public APIs only: the
/// frontmost app from NSWorkspace, and its frontmost normal on-screen window
/// from the window server's front-to-back list. No Accessibility permission.
@MainActor
final class WindowInUseDetector {
    var onAppInUseChange: (() -> Void)?

    private let ownProcessID = ProcessInfo.processInfo.processIdentifier
    private var lastExternalApp: NSRunningApplication?
    private var observer: (any NSObjectProtocol)?

    init() {
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownProcessID {
            lastExternalApp = front
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.frontmostAppChanged() }
        }
    }

    func observe() -> WindowObservation {
        var observation = WindowObservation()
        observation.isScreenLocked = Self.isScreenLocked
        observation.isSecureInputActive = IsSecureEventInputEnabled()

        guard let app = appInUse else { return observation }
        observation.appName = app.localizedName
        observation.processID = app.processIdentifier
        guard let bundleIdentifier = app.bundleIdentifier else {
            observation.app = .unidentified
            return observation
        }
        observation.app = .app(bundleIdentifier: bundleIdentifier)
        observation.bundleIdentifier = bundleIdentifier

        if let (windowID, frame) = Self.frontWindow(ofProcess: app.processIdentifier) {
            observation.window = WindowIdentity(windowID: windowID, bundleIdentifier: bundleIdentifier)
            observation.windowFrame = frame
        }
        return observation
    }

    /// The frontmost app, or, while Whoosh's own window is in front, the app
    /// that was in use before it. Whoosh's UI never becomes the app in use (§5.1).
    private var appInUse: NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownProcessID {
            return front
        }
        guard let last = lastExternalApp, !last.isTerminated else { return nil }
        return last
    }

    private func frontmostAppChanged() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ownProcessID,
              front.processIdentifier != lastExternalApp?.processIdentifier
        else { return }
        lastExternalApp = front
        onAppInUseChange?()
    }

    /// The process's visible windows at the normal window level, front to back,
    /// narrowed by `WindowSelection`. Floating palettes, menus, and other apps'
    /// windows are never chosen.
    private static func frontWindow(ofProcess processID: pid_t) -> (CGWindowID, CGRect)? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        let candidates = windows.compactMap { info -> WindowCandidate? in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processID,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  ((info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0,
                  let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo)
            else { return nil }
            return WindowCandidate(windowID: windowID, frame: bounds)
        }
        guard let chosen = WindowSelection.windowInUse(candidates) else { return nil }
        return (chosen.windowID, chosen.frame)
    }

    /// Fails closed: if macOS doesn't report the session state, treat the
    /// screen as locked rather than capture behind a lock screen.
    private static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return true }
        let locked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        let onConsole = session[kCGSessionOnConsoleKey as String] as? Bool ?? true
        return locked || !onConsole
    }
}
