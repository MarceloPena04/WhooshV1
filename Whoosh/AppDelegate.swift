import AppKit

/// Owns Whoosh's menu-bar presence. Whoosh has no Dock icon and no main
/// window (LSUIElement); everything starts from this menu (§2.1).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "wind", accessibilityDescription: "Whoosh")
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        // Each launch starts paused (§3.1). Resume, Hush, and Look now arrive
        // with the capture work (§14, task 3).
        menu.addItem(NSMenuItem(title: "Whoosh is paused", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Whoosh", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }
}
