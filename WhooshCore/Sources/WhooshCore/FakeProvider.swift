import Foundation
import Synchronization

/// A provider adapter that replays scripted outcomes instead of calling a
/// network service. M0 uses it to drive the overlay before live AI (§10), and
/// tests use it with an injected clock to exercise delays and cancellation.
public final class FakeProvider: ProviderAdapter {
    public struct Step: Sendable {
        public enum Outcome: Sendable {
            case reply(ProviderReply)
            case failure(ProviderError)
        }

        public var delay: Duration
        public var outcome: Outcome

        public init(delay: Duration = .zero, outcome: Outcome) {
            self.delay = delay
            self.outcome = outcome
        }

        public static func reply(_ reply: ProviderReply, after delay: Duration = .zero) -> Step {
            Step(delay: delay, outcome: .reply(reply))
        }

        public static func failure(_ error: ProviderError, after delay: Duration = .zero) -> Step {
            Step(delay: delay, outcome: .failure(error))
        }
    }

    private struct State {
        var script: [Step]
        var receivedRequestIDs: [UUID] = []
    }

    private let fallback: Step
    private let clock: any Clock<Duration>
    private let state: Mutex<State>

    /// - Parameters:
    ///   - script: Steps consumed in order, one per request.
    ///   - fallback: The step used once the script runs out.
    ///   - clock: The clock that times each step's delay.
    public init(
        script: [Step] = [],
        fallback: Step = .reply(FakeProvider.sampleQuestion),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.fallback = fallback
        self.clock = clock
        self.state = Mutex(State(script: script))
    }

    /// Every request received, in order, including ones later cancelled.
    public var receivedRequestIDs: [UUID] {
        state.withLock { $0.receivedRequestIDs }
    }

    public func send(_ request: ObservationRequest) async throws -> ProviderReply {
        let step = state.withLock { state in
            state.receivedRequestIDs.append(request.id)
            return state.script.isEmpty ? fallback : state.script.removeFirst()
        }
        if step.delay > .zero {
            try await clock.sleep(for: step.delay)
        }
        try Task.checkCancellation()
        switch step.outcome {
        case .reply(let reply):
            return reply
        case .failure(let error):
            throw error
        }
    }
}

extension FakeProvider {
    /// The illustrative question from §6.2.
    public static let sampleQuestion = ProviderReply(payload: Data("""
        {
          "schema_version": 1,
          "observation": "A landing-page draft with a short headline is visible.",
          "uncertainty": "The intended audience is unknown.",
          "response_type": "question",
          "message": "Is this page for first-time visitors or existing users?",
          "animation_id": "question_arrival",
          "memory_candidates": []
        }
        """.utf8))
}
