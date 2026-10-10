import Foundation
import WhooshCore

extension ObservationRequest {
    /// A synthetic request: no real screen content (§11.1).
    static func fixture(id: UUID = UUID()) -> ObservationRequest {
        ObservationRequest(
            id: id,
            capturedAt: Date(timeIntervalSince1970: 0),
            target: .window(WindowIdentity(windowID: 42, bundleIdentifier: "com.example.Editor")),
            trigger: .manual,
            sessionRevision: 0,
            memoryRevision: 0,
            image: CapturedImage(format: .png, data: Data([0x89, 0x50, 0x4E, 0x47]), pixelWidth: 1, pixelHeight: 1)
        )
    }
}

/// Builds a §6.2 payload, omitting any field passed as `nil`.
func responsePayload(
    schemaVersion: Int = 1,
    type: String = "comment",
    message: String? = "The headline is short and clear.",
    observation: String? = "A landing-page draft is visible.",
    uncertainty: String? = "The audience is unknown.",
    animation: String? = "observation_arrival",
    extra: [String: Any] = [:]
) -> Data {
    var object: [String: Any] = ["schema_version": schemaVersion, "response_type": type]
    object["message"] = message
    object["observation"] = observation
    object["uncertainty"] = uncertainty
    object["animation_id"] = animation
    object.merge(extra) { _, new in new }
    return try! JSONSerialization.data(withJSONObject: object)
}
