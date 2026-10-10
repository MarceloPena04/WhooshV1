import Foundation

/// What started an observation (§5.2).
public enum ObservationTrigger: String, Sendable {
    case manual
    case ambient
}

/// The captured window and its owning application (§5.2). Holds identifiers
/// only: window and app titles must never reach logs or usage records (§8.2).
public struct WindowIdentity: Hashable, Sendable {
    public let windowID: UInt32
    public let bundleIdentifier: String

    public init(windowID: UInt32, bundleIdentifier: String) {
        self.windowID = windowID
        self.bundleIdentifier = bundleIdentifier
    }
}

/// An encoded capture of the window in use. It lives only in memory and is
/// released once the request completes or is cancelled (§8.1).
public struct CapturedImage: Sendable {
    public enum Format: String, Sendable {
        case png
        case jpeg
    }

    public let format: Format
    public let data: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(format: Format, data: Data, pixelWidth: Int, pixelHeight: Int) {
        self.format = format
        self.data = data
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// One bounded request to the provider: the captured image plus the local
/// metadata that every request carries (§5.2).
public struct ObservationRequest: Sendable, Identifiable {
    public let id: UUID
    public let capturedAt: Date
    public let window: WindowIdentity
    public let trigger: ObservationTrigger
    public let sessionRevision: Int
    public let memoryRevision: Int
    public let image: CapturedImage

    public init(
        id: UUID = UUID(),
        capturedAt: Date,
        window: WindowIdentity,
        trigger: ObservationTrigger,
        sessionRevision: Int,
        memoryRevision: Int,
        image: CapturedImage
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.window = window
        self.trigger = trigger
        self.sessionRevision = sessionRevision
        self.memoryRevision = memoryRevision
        self.image = image
    }
}
