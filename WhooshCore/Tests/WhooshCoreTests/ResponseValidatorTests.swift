import Foundation
import Testing
import WhooshCore

struct ResponseValidatorTests {
    @Test func acceptsTheSampleQuestion() throws {
        let response = try ResponseValidator.validate(FakeProvider.sampleQuestion.payload)
        #expect(response.kind == .question)
        #expect(response.message == "Is this page for first-time visitors or existing users?")
        #expect(response.gesture == .questionArrival)
    }

    @Test func silentResponseCarriesNoMessage() throws {
        let response = try ResponseValidator.validate(responsePayload(type: "silent", message: "Ignored."))
        #expect(response.kind == .silent)
        #expect(response.message.isEmpty)
    }

    @Test func rejectsMalformedPayloads() {
        #expect(throws: ResponseValidationError.malformed) {
            try ResponseValidator.validate(Data("not json".utf8))
        }
        #expect(throws: ResponseValidationError.malformed) {
            try ResponseValidator.validate(Data(#"{"schema_version": 1, "response_type": "comment", "message": 5}"#.utf8))
        }
        #expect(throws: ResponseValidationError.malformed) {
            try ResponseValidator.validate(Data(#"{"response_type": "comment", "message": "Hi."}"#.utf8))
        }
    }

    @Test func rejectsOtherSchemaVersions() {
        #expect(throws: ResponseValidationError.unsupportedSchemaVersion) {
            try ResponseValidator.validate(responsePayload(schemaVersion: 2))
        }
    }

    @Test func rejectsUnknownResponseTypes() {
        #expect(throws: ResponseValidationError.unknownResponseType) {
            try ResponseValidator.validate(responsePayload(type: "shout"))
        }
    }

    @Test(arguments: ["question", "comment"])
    func requiresMessageWhenSpeaking(type: String) {
        #expect(throws: ResponseValidationError.missingMessage) {
            try ResponseValidator.validate(responsePayload(type: type, message: nil))
        }
        #expect(throws: ResponseValidationError.missingMessage) {
            try ResponseValidator.validate(responsePayload(type: type, message: "  \n "))
        }
    }

    @Test func enforcesFieldLimits() throws {
        let limits = ResponseLimits.prototype
        _ = try ResponseValidator.validate(responsePayload(message: String(repeating: "a", count: limits.message)))

        #expect(throws: ResponseValidationError.tooLong(.message)) {
            try ResponseValidator.validate(responsePayload(message: String(repeating: "a", count: limits.message + 1)))
        }
        #expect(throws: ResponseValidationError.tooLong(.observation)) {
            try ResponseValidator.validate(responsePayload(observation: String(repeating: "a", count: limits.observation + 1)))
        }
        #expect(throws: ResponseValidationError.tooLong(.uncertainty)) {
            try ResponseValidator.validate(responsePayload(uncertainty: String(repeating: "a", count: limits.uncertainty + 1)))
        }
    }

    @Test(arguments: [String?.some("explode"), nil])
    func unknownOrMissingGestureFallsBackToStatic(animation: String?) throws {
        let response = try ResponseValidator.validate(responsePayload(animation: animation))
        #expect(response.gesture == .staticFallback)
    }

    @Test func ignoresMemoryCandidatesBeforeM3() throws {
        let payload = responsePayload(extra: ["memory_candidates": [["not": "a string"]]])
        #expect(try ResponseValidator.validate(payload).kind == .comment)
    }
}
