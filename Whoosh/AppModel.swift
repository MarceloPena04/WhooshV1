import AppKit
import Observation
import OSLog
import WhooshCore

/// The app coordinator (§4.2). Only this type authorizes capture, provider
/// dispatch, display, and saving; a model response is a proposal, never an
/// instruction.
@MainActor
@Observable
final class AppModel {
    /// Each launch starts paused (§3.1).
    private(set) var isPaused = true
    private(set) var isHushed = false
    private(set) var hasPermission = ScreenRecordingPermission.isGranted
    private(set) var settings: AppSettings
    /// The settings file exists but couldn't be read. Changes then stay in
    /// memory, so the file is never silently replaced (§9).
    private(set) var settingsUnreadable = false
    private(set) var eligibility: Eligibility = .skipped(.paused)
    private(set) var appInUseName: String?
    private(set) var appInUseBundleIdentifier: String?
    var unavailableShortcuts: [Shortcut] = []
    /// Test builds only: the last image that would have gone to the provider,
    /// kept in memory for the boundary tests (§14, task 4). Always nil in
    /// release builds. Cleared on Pause, sleep, and lock; never written to disk.
    private(set) var lastCapture: DebugCapture?
    /// Test builds only: replies take 5 seconds, leaving time to Pause or switch apps mid-request.
    var slowReplies = false

    var indicator: StatusIndicator { StatusIndicator(eligibility: eligibility, isHushed: isHushed) }
    var isLooking: Bool { gate.isBusy }

    @ObservationIgnored var onIndicatorChange: (() -> Void)?

    private let policy: EligibilityPolicy
    private let store: SettingsStore
    private let detector = WindowInUseDetector()
    private let capturer = WindowCapturer()
    private let overlay = OverlayController()
    /// M0 has no model: placeholder replies after a short pretend delay.
    private let provider: any ProviderAdapter = FakeProvider(
        script: [
            .reply(FakeProvider.placeholderComment, after: .milliseconds(700)),
            .reply(FakeProvider.placeholderQuestion, after: .milliseconds(700)),
        ],
        repeatsScript: true
    )
    private let slowProvider: any ProviderAdapter = FakeProvider(
        script: [
            .reply(FakeProvider.placeholderComment, after: .seconds(5)),
            .reply(FakeProvider.placeholderQuestion, after: .seconds(5)),
        ],
        repeatsScript: true
    )
    @ObservationIgnored private var gate = ObservationGate()
    @ObservationIgnored private var lookTask: Task<Void, Never>?
    @ObservationIgnored private var lastObservation = WindowObservation()
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init() {
        policy = EligibilityPolicy(ownBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.olecramanep.Whoosh")
        store = SettingsStore(fileURL: URL.applicationSupportDirectory.appending(path: "Whoosh/settings.json"))
        do {
            settings = try store.load()
        } catch {
            settings = AppSettings()
            settingsUnreadable = true
            Log.lifecycle.error("Settings unreadable (\(String(describing: error), privacy: .public)); using defaults without saving")
        }
        detector.onAppInUseChange = { [weak self] in self?.appInUseChanged() }
        observeSystemEvents()
        refresh()
        Log.lifecycle.notice("Launched paused; permission \(self.hasPermission ? "granted" : "missing", privacy: .public)")
    }

    // MARK: - State

    /// Re-reads the permission and the window in use, and re-evaluates eligibility.
    func refresh() {
        hasPermission = ScreenRecordingPermission.isGranted
        let observation = detector.observe()
        lastObservation = observation
        appInUseName = observation.appName
        appInUseBundleIdentifier = observation.bundleIdentifier
        let input = EligibilityInput(
            scope: settings.captureScope,
            isPaused: isPaused,
            hasCapturePermission: hasPermission,
            isScreenLocked: observation.isScreenLocked,
            isSecureInputActive: observation.isSecureInputActive,
            app: observation.app,
            window: observation.window,
            displayID: observation.displayID
        )
        eligibility = policy.evaluate(input, exclusions: settings.exclusions)
        onIndicatorChange?()
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    func resume() {
        isPaused = false
        refresh()
        Log.lifecycle.notice("Resumed")
    }

    /// Stops new capture, cancels work in flight, and closes the bubble (§3.4).
    func pause() {
        isPaused = true
        lastCapture = nil
        invalidateWork()
        overlay.dismiss(animated: false)
        refresh()
        Log.lifecycle.notice("Paused")
    }

    /// Hush is about interruptions, not privacy: turning it on drops pending
    /// output and closes the bubble immediately (§3.4).
    func toggleHush() {
        isHushed.toggle()
        if isHushed {
            invalidateWork()
            overlay.dismiss(animated: false)
        }
        refresh()
        Log.lifecycle.notice("Hush \(self.isHushed ? "on" : "off", privacy: .public)")
    }

    func dismissBubble() {
        overlay.dismiss(animated: true)
    }

    func handle(_ shortcut: Shortcut) {
        switch shortcut {
        case .lookNow: lookNow()
        case .togglePause: togglePause()
        case .toggleHush: toggleHush()
        case .dismissBubble: dismissBubble()
        }
    }

    // MARK: - Look now

    /// One deliberate observation of the window in use (§3.4).
    func lookNow() {
        if isPaused {
            overlay.showNotice("Whoosh is paused. Resume it to look (\(Shortcut.togglePause.displayText)).", nearWindowAt: lastObservation.windowFrame)
            return
        }
        if isHushed {
            overlay.showNotice("Hush is on. Turn it off to use Look Now (\(Shortcut.toggleHush.displayText)).", nearWindowAt: lastObservation.windowFrame)
            return
        }
        // One observation in flight; repeated triggers are dropped, not queued (§5.3).
        guard !gate.isBusy else {
            Log.capture.notice("Look now ignored: one is already in flight")
            return
        }

        refresh()
        let observation = lastObservation
        guard case .eligible(let target) = eligibility, let processID = observation.processID else {
            if case .skipped(let reason) = eligibility {
                overlay.showNotice(
                    Self.describe(reason, appName: observation.appName, bundleIdentifier: observation.bundleIdentifier),
                    nearWindowAt: observation.windowFrame ?? observation.displayFrame
                )
                Log.capture.notice("Look now skipped: \(reason.rawValue, privacy: .public)")
            }
            return
        }
        guard let token = gate.begin(for: target) else { return }
        lookTask = Task { await look(token: token, processID: processID, observation: observation) }
    }

    private func look(token: ObservationGate.Token, processID: pid_t, observation: WindowObservation) async {
        defer { gate.finish(token) }
        let started = ContinuousClock.now
        let bubbleFrame = observation.windowFrame ?? observation.displayFrame
        do {
            let image = switch token.target {
            case .window(let window):
                try await capturer.captureWindow(window, processID: processID, includesPointer: settings.includesPointer)
            case .display(let display):
                try await capturer.captureDisplay(
                    display,
                    exclusions: ScreenExclusions(list: settings.exclusions, ownBundleIdentifier: policy.ownBundleIdentifier),
                    focusWindowFrame: display.focusWindow == nil ? nil : observation.windowFrame,
                    includesPointer: settings.includesPointer
                )
            }
            let captureDuration = ContinuousClock.now - started
            // Validate again before dispatch (§5.1).
            guard isStillCurrent(token) else {
                Log.capture.notice("Discarded before dispatch: context changed")
                return
            }
            let request = ObservationRequest(
                capturedAt: .now,
                target: token.target,
                trigger: .manual,
                sessionRevision: 0,
                memoryRevision: 0,
                image: image
            )
            #if DEBUG
            lastCapture = DebugCapture(target: token.target, image: image, capturedAt: request.capturedAt)
            let reply = try await (slowReplies ? slowProvider : provider).send(request)
            #else
            let reply = try await provider.send(request)
            #endif
            let response = try ResponseValidator.validate(reply.payload)
            // And again before display (§5.2).
            guard isStillCurrent(token) else {
                Log.capture.notice("Discarded before display: context changed")
                return
            }
            Log.capture.notice("Look now: \(response.kind.rawValue, privacy: .public), \(Self.scopeName(token.target), privacy: .public), \(image.pixelWidth, privacy: .public)x\(image.pixelHeight, privacy: .public) px, capture \(captureDuration.milliseconds, privacy: .public) ms")
            guard response.kind != .silent else { return }
            overlay.show(
                BubbleContent(
                    style: response.kind == .question ? .question : .comment,
                    message: response.message,
                    gesture: response.gesture,
                    footnote: Self.debugFootnote(target: token.target, image: image, captureDuration: captureDuration)
                ),
                nearWindowAt: bubbleFrame
            )
        } catch is CancellationError {
            Log.capture.notice("Look now cancelled")
        } catch {
            let nsError = error as NSError
            Log.capture.error("Look now failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            if isStillCurrent(token) {
                overlay.showNotice("Whoosh couldn't capture that.", nearWindowAt: bubbleFrame)
            }
        }
    }

    /// Whether work for `token` may still show anything: not invalidated, not
    /// paused or hushed, and the same window (and display) is still in use and eligible.
    private func isStillCurrent(_ token: ObservationGate.Token) -> Bool {
        guard gate.isCurrent(token), !isPaused, !isHushed else { return false }
        refresh()
        return eligibility == .eligible(token.target)
    }

    private func invalidateWork() {
        gate.invalidate()
        lookTask?.cancel()
        lookTask = nil
    }

    private func appInUseChanged() {
        if gate.isBusy {
            invalidateWork()
            Log.capture.notice("Discarded: app in use changed")
        }
        refresh()
    }

    // MARK: - Settings

    func setCaptureScope(_ scope: CaptureScope) {
        guard scope != settings.captureScope else { return }
        updateSettings { $0.captureScope = scope }
        invalidateWork()
        refresh()
        Log.lifecycle.notice("Capture scope: \(scope.rawValue, privacy: .public)")
    }

    func setIncludesPointer(_ includesPointer: Bool) {
        updateSettings { $0.includesPointer = includesPointer }
        Log.lifecycle.notice("Pointer in captures: \(includesPointer ? "on" : "off", privacy: .public)")
    }

    func excludeAppInUse() {
        guard let bundleIdentifier = appInUseBundleIdentifier else { return }
        addExclusion(ExcludedApp(bundleIdentifier: bundleIdentifier, name: appInUseName ?? bundleIdentifier))
    }

    func addExclusion(_ app: ExcludedApp) {
        updateSettings { $0.exclusions.add(app) }
        invalidateWork()
        refresh()
    }

    func removeExclusion(_ bundleIdentifier: String) {
        updateSettings { $0.exclusions.remove(bundleIdentifier) }
        refresh()
    }

    func restoreDefaultExclusions() {
        updateSettings { $0.exclusions = .defaults }
        invalidateWork()
        refresh()
    }

    // MARK: - Permission and onboarding

    func requestPermission() {
        if settings.screenRecordingRequested {
            ScreenRecordingPermission.openSystemSettings()
        } else {
            updateSettings { $0.screenRecordingRequested = true }
            ScreenRecordingPermission.request()
        }
        refresh()
    }

    func completeOnboarding() {
        updateSettings { $0.onboardingCompleted = true }
        resume()
    }

    // MARK: - Private

    private func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        guard !settingsUnreadable else { return }
        do {
            try store.save(settings)
        } catch {
            Log.lifecycle.error("Settings not saved")
        }
    }

    /// Sleep, lock, and user switching drop work in flight; nothing is replayed afterwards (§9).
    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.systemBecameUnavailable() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.systemBecameUnavailable() }
        })
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    private func systemBecameUnavailable() {
        lastCapture = nil
        invalidateWork()
        overlay.dismiss(animated: false)
        refresh()
    }

    static func describe(_ reason: SkipReason, appName: String?, bundleIdentifier: String?) -> String {
        let app = appName ?? "This app"
        return switch reason {
        case .paused: "Whoosh is paused."
        case .permissionMissing: "Whoosh needs the Screen Recording permission."
        case .screenLocked: "The screen is locked."
        case .unidentifiedApp: "Skipping \(app): it can't be checked against your excluded apps."
        case .ownApp: "Whoosh doesn't look at its own windows."
        case .excludedApp: "Skipping \(app): it's on your excluded apps list."
        case .secureInput: "Skipping: a password field is active."
        case .noWindow where bundleIdentifier?.lowercased() == "com.apple.finder":
            "The desktop is in front. Click into a window, or choose Whole Screen in Whoosh's menu."
        case .noWindow: "\(app) has no window to look at."
        case .noDisplay: "Whoosh can't tell which screen you're using."
        }
    }

    private static func scopeName(_ target: CaptureTarget) -> String {
        switch target {
        case .window: "window"
        case .display: "screen"
        }
    }

    private static func debugFootnote(target: CaptureTarget, image: CapturedImage, captureDuration: Duration) -> String? {
        #if DEBUG
        let scope = switch target {
        case .window: "window"
        case .display: image.focusRegion == nil ? "whole screen, desktop in front" : "whole screen"
        }
        return "Placeholder · \(scope) · \(image.pixelWidth)×\(image.pixelHeight) px in \(captureDuration.milliseconds) ms"
        #else
        return nil
        #endif
    }
}

private extension Duration {
    var milliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
