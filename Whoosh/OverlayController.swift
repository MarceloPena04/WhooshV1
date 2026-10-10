import AppKit
import SwiftUI

/// A borderless panel that never becomes key or activates Whoosh, so a bubble
/// appearing while the user types cannot take their keystrokes (§3.3). It joins
/// all Spaces and can float over full-screen apps (§4.4).
private final class BubblePanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        canHide = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Shows at most one bubble at a time; a new one replaces the old, and missed
/// bubbles are never queued (§3.3).
@MainActor
final class OverlayController {
    private static let margin: CGFloat = 4
    private static let resumeAfterHover: Duration = .seconds(4)

    private var panel: NSPanel?
    private var fadeTask: Task<Void, Never>?

    var isVisible: Bool { panel != nil }

    /// - Parameter windowFrame: The window in use, in global display
    ///   coordinates; the bubble goes in the bottom-right corner of its display.
    func show(_ content: BubbleContent, nearWindowAt windowFrame: CGRect?, for duration: Duration = .seconds(8)) {
        dismiss(animated: false)
        guard let screen = ScreenGeometry.screen(containing: windowFrame) else { return }

        let view = BubbleView(
            content: content,
            onHover: { [weak self] hovering in self?.hoverChanged(hovering) },
            onClose: { [weak self] in self?.dismiss(animated: true) }
        )
        let hostingView = NSHostingView(rootView: view)
        let size = hostingView.fittingSize
        let visible = screen.visibleFrame
        let origin = CGPoint(x: visible.maxX - size.width - Self.margin, y: visible.minY + Self.margin)

        let panel = BubblePanel(contentRect: CGRect(origin: origin, size: size))
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel
        scheduleFade(after: duration)
        Log.overlay.info("Bubble shown")
    }

    func showNotice(_ message: String, nearWindowAt windowFrame: CGRect?) {
        show(BubbleContent(style: .notice, message: message, gesture: .staticFallback), nearWindowAt: windowFrame, for: .seconds(4))
    }

    /// Without animation, the bubble disappears and all motion stops at once,
    /// as Hush and Pause require (§3.4).
    func dismiss(animated: Bool) {
        fadeTask?.cancel()
        fadeTask = nil
        guard let panel else { return }
        self.panel = nil
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated { panel.orderOut(nil) }
            }
        } else {
            panel.orderOut(nil)
        }
    }

    /// Fading pauses while the pointer is over the bubble (§3.3).
    private func hoverChanged(_ hovering: Bool) {
        guard isVisible else { return }
        if hovering {
            fadeTask?.cancel()
        } else {
            scheduleFade(after: Self.resumeAfterHover)
        }
    }

    private func scheduleFade(after duration: Duration) {
        fadeTask?.cancel()
        fadeTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.dismiss(animated: true)
        }
    }
}
