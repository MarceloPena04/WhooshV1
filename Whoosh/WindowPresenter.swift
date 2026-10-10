import AppKit
import SwiftUI

/// Opens Whoosh's own windows (onboarding and settings). While one is in
/// front, the app in use stays the one the user was working in (§5.1).
@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {
    private var windows: [String: NSWindow] = [:]

    func showOnboarding(model: AppModel) {
        show(id: "onboarding", title: "Welcome to Whoosh") {
            OnboardingView(model: model) { [weak self] in self?.close(id: "onboarding") }
        }
    }

    func showSettings(model: AppModel) {
        show(id: "settings", title: "Whoosh Settings") {
            SettingsView(model: model)
        }
    }

    func showCaptureViewer(model: AppModel) {
        show(id: "capture", title: "Last Capture (test build)", resizable: true) {
            CaptureViewerView(model: model)
        }
    }

    private func show<Content: View>(id: String, title: String, resizable: Bool = false, @ViewBuilder content: () -> Content) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
        window.title = title
        window.styleMask = resizable ? [.titled, .closable, .resizable, .miniaturizable] : [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func close(id: String) {
        windows[id]?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windows = windows.filter { $0.value !== window }
        // Hand the keyboard back to the app the user was working in.
        if windows.isEmpty { NSApp.hide(nil) }
    }
}
