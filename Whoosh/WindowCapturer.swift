import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
import WhooshCore

enum CaptureError: Error {
    case windowUnavailable
    case displayUnavailable
    case encodingFailed
}

/// Captures what the capture scope allows (§5.1). The image stays in memory;
/// nothing is written to disk (§8.2).
struct WindowCapturer: Sendable {
    /// Whole screen: one display, menu bar included, through a filter that
    /// removes excluded apps, Whoosh, and private system surfaces. The window
    /// server leaves those windows out, so what lies behind shows through.
    func captureDisplay(
        _ target: DisplayTarget,
        exclusions: ScreenExclusions,
        focusWindowFrame: CGRect?,
        includesPointer: Bool
    ) async throws -> CapturedImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == target.displayID }) else {
            throw CaptureError.displayUnavailable
        }
        let hidden = content.applications.filter {
            exclusions.excludes(bundleIdentifier: $0.bundleIdentifier, processName: $0.applicationName)
        }
        let filter = SCContentFilter(display: display, excludingApplications: hidden, exceptingWindows: [])
        let scale = CGFloat(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(CGFloat(display.width) * scale))
        configuration.height = max(1, Int(CGFloat(display.height) * scale))
        configuration.showsCursor = includesPointer

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let data = Self.pngData(from: image) else { throw CaptureError.encodingFailed }
        let focusRegion = focusWindowFrame.flatMap {
            FocusRegion.pixels(window: $0, display: display.frame, scale: scale)
        }
        return CapturedImage(format: .png, data: data, pixelWidth: image.width, pixelHeight: image.height, focusRegion: focusRegion)
    }

    /// This window: exactly one window through a single-window content filter,
    /// so neighbouring windows and Whoosh's own overlay cannot appear.
    func captureWindow(_ window: WindowIdentity, processID: pid_t, includesPointer: Bool) async throws -> CapturedImage {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        // Re-check identity right before capture: the same window ID, still on
        // screen, still owned by the same process and app.
        guard let target = content.windows.first(where: { $0.windowID == window.windowID }),
              target.isOnScreen,
              let owner = target.owningApplication,
              owner.processID == processID,
              owner.bundleIdentifier.lowercased() == window.bundleIdentifier.lowercased()
        else { throw CaptureError.windowUnavailable }

        let filter = SCContentFilter(desktopIndependentWindow: target)
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = max(1, Int(filter.contentRect.width * scale))
        configuration.height = max(1, Int(filter.contentRect.height * scale))
        configuration.showsCursor = includesPointer
        configuration.ignoreShadowsSingleWindow = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let data = Self.pngData(from: image) else { throw CaptureError.encodingFailed }
        return CapturedImage(format: .png, data: data, pixelWidth: image.width, pixelHeight: image.height)
    }

    private static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
