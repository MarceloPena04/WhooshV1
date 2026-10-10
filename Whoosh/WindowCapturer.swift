import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
import WhooshCore

enum CaptureError: Error {
    case windowUnavailable
    case encodingFailed
}

/// Captures exactly one window with a single-window content filter (§5.1), so
/// neighbouring windows and Whoosh's own overlay cannot appear in the image.
/// The image stays in memory; nothing is written to disk (§8.2).
struct WindowCapturer: Sendable {
    func capture(_ window: WindowIdentity, processID: pid_t) async throws -> CapturedImage {
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
        configuration.showsCursor = false
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
