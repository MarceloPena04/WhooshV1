import AppKit
import WhooshCore

/// The menu-bar icon and its menu. The icon shows whether Whoosh is ready,
/// paused, hushed, or skipping (§2.1); the menu is rebuilt each time it opens.
/// Opening it doesn't activate Whoosh, so the app in use stays the same (§5.1).
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let windows: WindowPresenter
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(model: AppModel, windows: WindowPresenter) {
        self.model = model
        self.windows = windows
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        updateIcon()
    }

    func updateIcon() {
        let (symbol, description) = switch model.indicator {
        case .ready: ("wind", "Whoosh is ready")
        case .paused: ("pause.circle", "Whoosh is paused")
        case .hushed: ("bell.slash", "Whoosh is hushed")
        case .needsPermission: ("exclamationmark.triangle", "Whoosh needs the Screen Recording permission")
        case .skipping: ("eye.slash", "Whoosh is skipping this window")
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refresh()
        menu.removeAllItems()

        menu.addItem(note(statusLine))
        if model.isHushed {
            menu.addItem(note("Hush is on: no bubbles"))
        }
        if model.settingsUnreadable {
            menu.addItem(note("Settings couldn't be read; changes won't be saved"))
        }
        if !model.unavailableShortcuts.isEmpty {
            let keys = model.unavailableShortcuts.map(\.displayText).joined(separator: ", ")
            menu.addItem(note("Taken by another app: \(keys)"))
        }
        menu.addItem(.separator())

        menu.addItem(item(model.isPaused ? "Resume" : "Pause", #selector(togglePause), shortcut: .togglePause))
        let hush = item("Hush", #selector(toggleHush), shortcut: .toggleHush)
        hush.state = model.isHushed ? .on : .off
        menu.addItem(hush)
        menu.addItem(lookNowItem)
        menu.addItem(.separator())

        menu.addItem(note("Look At"))
        let thisWindow = item("This Window", #selector(lookAtThisWindow))
        thisWindow.state = model.settings.captureScope == .window ? .on : .off
        menu.addItem(thisWindow)
        let wholeScreen = item("Whole Screen", #selector(lookAtWholeScreen))
        wholeScreen.state = model.settings.captureScope == .screen ? .on : .off
        menu.addItem(wholeScreen)
        let pointer = item("Include Pointer", #selector(toggleIncludesPointer))
        pointer.state = model.settings.includesPointer ? .on : .off
        menu.addItem(pointer)
        menu.addItem(.separator())

        if let name = model.appInUseName, let bundleIdentifier = model.appInUseBundleIdentifier {
            if model.settings.exclusions.contains(bundleIdentifier) {
                menu.addItem(item("Stop Excluding “\(name)”", #selector(stopExcludingAppInUse)))
            } else {
                menu.addItem(item("Exclude “\(name)”", #selector(excludeAppInUse)))
            }
        }
        menu.addItem(item("Settings…", #selector(showSettings)))
        if !model.hasPermission {
            menu.addItem(item("Allow Screen Recording…", #selector(requestPermission)))
        }
        menu.addItem(item("Welcome to Whoosh…", #selector(showOnboarding)))
        menu.addItem(.separator())
        #if DEBUG
        menu.addItem(note("Test Build"))
        menu.addItem(item("Show Last Capture…", #selector(showCaptureViewer)))
        let slow = item("Slow Placeholder Replies (5 s)", #selector(toggleSlowReplies))
        slow.state = model.slowReplies ? .on : .off
        menu.addItem(slow)
        menu.addItem(.separator())
        #endif
        menu.addItem(NSMenuItem(title: "Quit Whoosh", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private var statusLine: String {
        switch model.eligibility {
        case .eligible(.window): "Ready to look at \(model.appInUseName ?? "this window")"
        case .eligible(.display): "Ready to look at the whole screen"
        case .skipped(let reason):
            AppModel.describe(reason, appName: model.appInUseName, bundleIdentifier: model.appInUseBundleIdentifier)
        }
    }

    /// Look Now is disabled while paused or hushed, and says which control to change (§3.4).
    private var lookNowItem: NSMenuItem {
        let title: String
        var enabled = false
        if model.isPaused {
            title = "Look Now (resume first)"
        } else if model.isHushed {
            title = "Look Now (turn off Hush first)"
        } else if model.isLooking {
            title = "Looking…"
        } else {
            title = "Look Now"
            if case .eligible = model.eligibility { enabled = true }
        }
        let item = item(title, #selector(lookNow), shortcut: .lookNow)
        item.isEnabled = enabled
        return item
    }

    private func note(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func item(_ title: String, _ action: Selector, shortcut: Shortcut? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let shortcut, !model.unavailableShortcuts.contains(shortcut) {
            item.keyEquivalent = shortcut.key
            item.keyEquivalentModifierMask = Shortcut.modifierFlags
        }
        return item
    }

    @objc private func togglePause() { model.togglePause() }
    @objc private func toggleHush() { model.toggleHush() }
    @objc private func lookNow() { model.lookNow() }
    @objc private func excludeAppInUse() { model.excludeAppInUse() }
    @objc private func requestPermission() { model.requestPermission() }
    @objc private func lookAtThisWindow() { model.setCaptureScope(.window) }
    @objc private func lookAtWholeScreen() { model.setCaptureScope(.screen) }
    @objc private func toggleIncludesPointer() { model.setIncludesPointer(!model.settings.includesPointer) }
    @objc private func showSettings() { windows.showSettings(model: model) }
    @objc private func showCaptureViewer() { windows.showCaptureViewer(model: model) }
    @objc private func toggleSlowReplies() { model.slowReplies.toggle() }
    @objc private func showOnboarding() { windows.showOnboarding(model: model) }

    @objc private func stopExcludingAppInUse() {
        guard let bundleIdentifier = model.appInUseBundleIdentifier else { return }
        model.removeExclusion(bundleIdentifier)
    }
}
