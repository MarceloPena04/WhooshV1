import AppKit

/// Converts between the window server's global display coordinates (points,
/// origin at the top left of the main display) and AppKit's screens (origin
/// at the bottom left).
@MainActor
enum ScreenGeometry {
    /// The screen holding most of `frame`, or the main screen when `frame` is nil.
    static func screen(containing frame: CGRect?) -> NSScreen? {
        let screens = NSScreen.screens
        guard let frame, let primary = screens.first else { return NSScreen.main ?? screens.first }
        let flipped = CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
        func overlap(_ screen: NSScreen) -> CGFloat {
            let intersection = screen.frame.intersection(flipped)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        return screens.max { overlap($0) < overlap($1) }
    }

    static func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// The menu bar's height on `screen`, including the camera housing on
    /// displays with a notch; zero when the menu bar hides itself.
    static func menuBarHeight(of screen: NSScreen) -> CGFloat {
        max(screen.frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)
    }
}
