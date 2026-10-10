import Testing
import WhooshCore

struct ObservationGateTests {
    private let window = CaptureTarget.window(WindowIdentity(windowID: 1, bundleIdentifier: "com.example.Editor"))

    @Test func admitsOneObservationAtATime() throws {
        var gate = ObservationGate()
        let begun = gate.begin(for: window)
        let token = try #require(begun)
        #expect(gate.begin(for: window) == nil)

        gate.finish(token)
        #expect(!gate.isBusy)
        #expect(gate.begin(for: window) != nil)
    }

    @Test func invalidationMakesOutstandingWorkStale() throws {
        var gate = ObservationGate()
        let begunFirst = gate.begin(for: window)
        let stale = try #require(begunFirst)
        gate.invalidate()
        #expect(!gate.isCurrent(stale))

        let begunAgain = gate.begin(for: window)
        let fresh = try #require(begunAgain)
        #expect(gate.isCurrent(fresh))
        #expect(!gate.isCurrent(stale))

        // A stale observation finishing late must not release the fresh one.
        gate.finish(stale)
        #expect(gate.isCurrent(fresh))
    }
}
