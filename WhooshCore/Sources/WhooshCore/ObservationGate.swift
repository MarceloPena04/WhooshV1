import Foundation

/// Admits one observation at a time (§5.3) and lets later events invalidate
/// it (§5.2): Pause, Hush, a change of window, sleep, or a new exclusion.
/// Work holding an invalidated token must not display or persist anything.
public struct ObservationGate: Sendable {
    public struct Token: Sendable, Equatable {
        fileprivate let generation: Int
        public let target: CaptureTarget
    }

    private var generation = 0
    public private(set) var inFlight: Token?

    public init() {}

    public var isBusy: Bool { inFlight != nil }

    /// Returns nil while another observation is in flight, so repeated
    /// triggers are debounced rather than queued.
    public mutating func begin(for target: CaptureTarget) -> Token? {
        guard inFlight == nil else { return nil }
        generation += 1
        let token = Token(generation: generation, target: target)
        inFlight = token
        return token
    }

    public func isCurrent(_ token: Token) -> Bool {
        inFlight == token
    }

    public mutating func finish(_ token: Token) {
        if inFlight == token { inFlight = nil }
    }

    public mutating func invalidate() {
        generation += 1
        inFlight = nil
    }
}
