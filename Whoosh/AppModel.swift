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
        Log.lifecycle.info("Launched paused; permission \(self.hasPermission ? "granted" : "missing", privacy: .public)")
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
            isPaused: isPaused,
            hasCapturePermission: hasPermission,
            isScreenLocked: observation.isScreenLocked,
            isSecureInputActive: observation.isSecureInputActive,
            app: observation.app,
            window: observation.window
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
        Log.lifecycle.info("Resumed")
    }

    /// Stops new capture, cancels work in flight, and closes the bubble (§3.4).
    func pause() {
        isPaused = true
        invalidateWork()
        overlay.dismiss(animated: false)
        refresh()
        Log.lifecycle.info("Paused")
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
        Log.lifecycle.info("Hush \(self.isHushed ? "on" : "off", privacy: .public)")
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
        guard !gate.isBusy else { return }

        refresh()
        let observation = lastObservation
        guard case .eligible(let window) = eligibility, let processID = observation.processID else {
            if case .skipped(let reason) = eligibility {
                overlay.showNotice(Self.describe(reason, appName: observation.appName), nearWindowAt: observation.windowFrame)
                Log.capture.info("Look now skipped: \(reason.rawValue, privacy: .public)")
            }
            return
        }
        guard let token = gate.begin(for: window) else { return }
        lookTask = Task { await look(token: token, processID: processID, windowFrame: observation.windowFrame) }
    }

    private func look(token: ObservationGate.Token, processID: pid_t, windowFrame: CGRect?) async {
        defer { gate.finish(token) }
        let started = ContinuousClock.now
        do {
            let image = try await capturer.capture(token.window, processID: processID)
            let captureDuration = ContinuousClock.now - started
            // Validate again before dispatch (§5.1).
            guard isStillCurrent(token) else {
                Log.capture.info("Discarded before dispatch: context changed")
                return
            }
            let request = ObservationRequest(
                capturedAt: .now,
                window: token.window,
                trigger: .manual,
                sessionRevision: 0,
                memoryRevision: 0,
                image: image
            )
            let reply = try await provider.send(request)
            let response = try ResponseValidator.validate(reply.payload)
            // And again before display (§5.2).
            guard isStillCurrent(token) else {
                Log.capture.info("Discarded before display: context changed")
                return
            }
            Log.capture.info("Look now: \(response.kind.rawValue, privacy: .public), \(image.pixelWidth, privacy: .public)x\(image.pixelHeight, privacy: .public) px, capture \(captureDuration.milliseconds, privacy: .public) ms")
            guard response.kind != .silent else { return }
            overlay.show(
                BubbleContent(
                    style: response.kind == .question ? .question : .comment,
                    message: response.message,
                    gesture: response.gesture,
                    footnote: Self.debugFootnote(image: image, captureDuration: captureDuration)
                ),
                nearWindowAt: windowFrame
            )
        } catch is CancellationError {
            Log.capture.info("Look now cancelled")
        } catch {
            let nsError = error as NSError
            Log.capture.error("Look now failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            if isStillCurrent(token) {
                overlay.showNotice("Whoosh couldn't capture this window.", nearWindowAt: windowFrame)
            }
        }
    }

    /// Whether work for `token` may still show anything: not invalidated, not
    /// paused or hushed, and the same window is still in use and eligible.
    private func isStillCurrent(_ token: ObservationGate.Token) -> Bool {
        guard gate.isCurrent(token), !isPaused, !isHushed else { return false }
        refresh()
        return eligibility == .eligible(token.window)
    }

    private func invalidateWork() {
        gate.invalidate()
        lookTask?.cancel()
        lookTask = nil
    }

    private func appInUseChanged() {
        if gate.isBusy {
            invalidateWork()
            Log.capture.info("Discarded: app in use changed")
        }
        refresh()
    }

    // MARK: - Exclusions

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
        invalidateWork()
        overlay.dismiss(animated: false)
        refresh()
    }

    static func describe(_ reason: SkipReason, appName: String?) -> String {
        let app = appName ?? "This app"
        return switch reason {
        case .paused: "Whoosh is paused."
        case .permissionMissing: "Whoosh needs the Screen Recording permission."
        case .screenLocked: "The screen is locked."
        case .unidentifiedApp: "Skipping \(app): it can't be checked against your excluded apps."
        case .ownApp: "Whoosh doesn't look at its own windows."
        case .excludedApp: "Skipping \(app): it's on your excluded apps list."
        case .secureInput: "Skipping: a password field is active."
        case .noWindow: "There's no window to look at."
        }
    }

    private static func debugFootnote(image: CapturedImage, captureDuration: Duration) -> String? {
        #if DEBUG
        "Placeholder · captured \(image.pixelWidth)×\(image.pixelHeight) px in \(captureDuration.milliseconds) ms"
        #else
        nil
        #endif
    }
}

private extension Duration {
    var milliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
