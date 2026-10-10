import Foundation

/// Sends one observation to the model provider (§4.2) and returns the model's
/// structured output without interpreting it. The caller validates the payload
/// with `ResponseValidator` and owns retries, deadlines, and usage accounting,
/// so there is a single retry owner (§5.3).
public protocol ProviderAdapter: Sendable {
    func send(_ request: ObservationRequest) async throws -> ProviderReply
}

public struct ProviderReply: Sendable, Equatable {
    /// The model's §6.2 JSON object, not yet validated. Never display or log it.
    public let payload: Data
    /// Provider-reported usage, when the provider supplies it.
    public let usage: ProviderUsage?

    public init(payload: Data, usage: ProviderUsage? = nil) {
        self.payload = payload
        self.usage = usage
    }
}

public struct ProviderUsage: Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Content-free provider failures (§5.3, §9). Never carry provider error
/// bodies: they can echo the request (§8.1). Cancellation surfaces as
/// `CancellationError`, not as a provider error.
public enum ProviderError: Error, Sendable, Equatable {
    case invalidCredentials
    case quotaExhausted
    case rateLimited(retryAfter: Duration?)
    case transient
}
