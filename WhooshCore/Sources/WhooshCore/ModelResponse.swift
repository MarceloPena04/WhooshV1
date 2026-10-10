import Foundation

/// A model response that passed local validation (§6.2). Only this type,
/// never a raw provider payload, may reach the overlay.
public struct ModelResponse: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case silent
        case question
        case comment
    }

    public let kind: Kind
    /// Bubble text. Always empty for `.silent`.
    public let message: String
    /// Internal context: never displayed, and not durable memory (§6.2).
    public let observation: String
    public let uncertainty: String
    public let gesture: Gesture
}

/// The approved gestures a response may select (§3.3). The app renders them;
/// the model only names one.
public enum Gesture: String, Sendable, CaseIterable {
    case questionArrival = "question_arrival"
    case observationArrival = "observation_arrival"
    case acknowledgement
    /// Safe fallback for a missing or unknown animation ID: no motion.
    case staticFallback = "static"
}

/// Field limits from §3.5. `memory_candidates` is ignored until M3.
public struct ResponseLimits: Sendable, Equatable {
    public var message: Int
    public var observation: Int
    public var uncertainty: Int

    public init(message: Int = 240, observation: Int = 300, uncertainty: Int = 200) {
        self.message = message
        self.observation = observation
        self.uncertainty = uncertainty
    }

    public static let prototype = ResponseLimits()
}

public enum ResponseField: String, Sendable {
    case message
    case observation
    case uncertainty
}

/// Why a payload was rejected. Deliberately content-free so it can be logged (§8.2).
public enum ResponseValidationError: Error, Sendable, Equatable {
    case malformed
    case unsupportedSchemaVersion
    case unknownResponseType
    case missingMessage
    case tooLong(ResponseField)
}

public enum ResponseValidator {
    public static let schemaVersion = 1

    /// Decodes and checks a provider payload against the §6.2 schema and the
    /// §3.5 limits. Unknown gestures fall back to `.staticFallback`.
    public static func validate(
        _ payload: Data,
        limits: ResponseLimits = .prototype
    ) throws(ResponseValidationError) -> ModelResponse {
        let wire: WireResponse
        do {
            wire = try JSONDecoder().decode(WireResponse.self, from: payload)
        } catch {
            throw .malformed
        }
        guard wire.schemaVersion == schemaVersion else { throw .unsupportedSchemaVersion }
        guard let kind = ModelResponse.Kind(rawValue: wire.responseType) else { throw .unknownResponseType }

        let observation = try bounded(wire.observation, limit: limits.observation, field: .observation)
        let uncertainty = try bounded(wire.uncertainty, limit: limits.uncertainty, field: .uncertainty)
        var message = ""
        if kind != .silent {
            message = try bounded(wire.message, limit: limits.message, field: .message)
            guard !message.isEmpty else { throw .missingMessage }
        }
        let gesture = wire.animationID.flatMap(Gesture.init(rawValue:)) ?? .staticFallback

        return ModelResponse(
            kind: kind,
            message: message,
            observation: observation,
            uncertainty: uncertainty,
            gesture: gesture
        )
    }

    private static func bounded(
        _ text: String?,
        limit: Int,
        field: ResponseField
    ) throws(ResponseValidationError) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= limit else { throw .tooLong(field) }
        return trimmed
    }
}

/// The §6.2 wire format. Unlisted fields, including `memory_candidates`, are ignored.
private struct WireResponse: Decodable {
    let schemaVersion: Int
    let responseType: String
    let message: String?
    let observation: String?
    let uncertainty: String?
    let animationID: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case responseType = "response_type"
        case message
        case observation
        case uncertainty
        case animationID = "animation_id"
    }
}
