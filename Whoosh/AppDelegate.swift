import AppKit

/// Wires Whoosh together at launch. Whoosh has no Dock icon and no main
/// window (LSUIElement); everything starts from the menu-bar menu (§2.1).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusMenu: StatusMenuController?
    private var hotKeys: HotKeyCenter?
    private let windows = WindowPresenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        let statusMenu = StatusMenuController(model: model, windows: windows)
        model.onIndicatorChange = { [weak statusMenu] in statusMenu?.updateIcon() }

        let hotKeys = HotKeyCenter { [weak model] shortcut in model?.handle(shortcut) }
        hotKeys.registerAll()
        model.unavailableShortcuts = hotKeys.unavailable

        self.model = model
        self.statusMenu = statusMenu
        self.hotKeys = hotKeys

        // Onboarding appears until the user finishes it once (§3.1).
        if !model.settings.onboardingCompleted {
            windows.showOnboarding(model: model)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
