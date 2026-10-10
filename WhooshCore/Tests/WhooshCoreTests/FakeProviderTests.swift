import Foundation
import Testing
import WhooshCore

struct FakeProviderTests {
    @Test func repliesInScriptOrderThenFallsBack() async throws {
        let first = ProviderReply(payload: responsePayload(message: "First."))
        let provider = FakeProvider(script: [.reply(first)])

        #expect(try await provider.send(.fixture()) == first)
        #expect(try await provider.send(.fixture()) == FakeProvider.sampleQuestion)
        #expect(provider.receivedRequestIDs.count == 2)
    }

    @Test func throwsScriptedFailures() async {
        let provider = FakeProvider(script: [.failure(.invalidCredentials), .failure(.rateLimited(retryAfter: .seconds(2)))])

        await #expect(throws: ProviderError.invalidCredentials) {
            try await provider.send(.fixture())
        }
        await #expect(throws: ProviderError.rateLimited(retryAfter: .seconds(2))) {
            try await provider.send(.fixture())
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func delayFollowsTheInjectedClock() async throws {
        let clock = ManualClock()
        let provider = FakeProvider(script: [.reply(FakeProvider.sampleQuestion, after: .seconds(5))], clock: clock)

        let pending = Task { try await provider.send(.fixture()) }
        await clock.waitForSleepers(1)
        clock.advance(by: .seconds(4))
        #expect(clock.sleeperCount == 1)

        clock.advance(by: .seconds(1))
        #expect(try await pending.value == FakeProvider.sampleQuestion)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellationDuringDelayDeliversNoReply() async {
        let clock = ManualClock()
        let request = ObservationRequest.fixture()
        let provider = FakeProvider(script: [.reply(FakeProvider.sampleQuestion, after: .seconds(30))], clock: clock)

        let pending = Task { try await provider.send(request) }
        await clock.waitForSleepers(1)
        pending.cancel()

        await #expect(throws: CancellationError.self) {
            try await pending.value
        }
        #expect(provider.receivedRequestIDs == [request.id])
    }

    @Test func cancelledTaskDeliversNoReplyEvenWithoutDelay() async {
        let provider = FakeProvider()
        let pending = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await provider.send(.fixture())
        }

        await #expect(throws: CancellationError.self) {
            try await pending.value
        }
    }
}
