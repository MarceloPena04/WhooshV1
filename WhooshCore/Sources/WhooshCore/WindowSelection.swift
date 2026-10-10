import CoreGraphics
import Foundation

/// A normal-level, visible window of the app in use, as the window server reports it.
public struct WindowCandidate: Sendable, Equatable {
    public let windowID: UInt32
    /// Global display coordinates, in points.
    public let frame: CGRect

    public init(windowID: UInt32, frame: CGRect) {
        self.windowID = windowID
        self.frame = frame
    }
}

/// Picks the window in use from the app's windows (§5.1).
public enum WindowSelection {
    /// Smaller windows are tooltips, badges, or thin title strips, not work.
    public static let minimumSide: CGFloat = 50

    /// - Parameter candidates: The app's windows in front-to-back order.
    /// - Returns: The frontmost window, unless it is a strip attached to a
    ///   window behind it, in which case the window it belongs to.
    public static func windowInUse(_ candidates: [WindowCandidate]) -> WindowCandidate? {
        let usable = candidates.filter { $0.frame.width >= minimumSide && $0.frame.height >= minimumSide }
        guard var chosen = usable.first else { return nil }
        // Some apps float a toolbar or title strip as its own window in front
        // of the window it belongs to; Safari and Chrome do this in full screen.
        // Capturing the strip would miss the work, so take its window instead.
        for candidate in usable.dropFirst() where isStrip(chosen.frame, attachedTo: candidate.frame) {
            chosen = candidate
        }
        return chosen
    }

    /// Same left edge and width, shorter, and overlapping or touching. Separate
    /// document windows almost never line up this exactly.
    static func isStrip(_ strip: CGRect, attachedTo window: CGRect) -> Bool {
        let tolerance: CGFloat = 2
        return abs(strip.minX - window.minX) <= tolerance
            && abs(strip.width - window.width) <= tolerance
            && strip.height < window.height
            && strip.minY <= window.maxY + tolerance
            && strip.maxY >= window.minY - tolerance
    }
}
