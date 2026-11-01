import Foundation

public protocol SurveyRepositoryProtocol: Sendable {
    func fetchScheduledSurvey(id: String) async throws -> SurveyConfig
    func listSurveys() async throws -> [SurveyConfig]
    func fetchScheduleConfig() async throws -> SamplingRules
    func submitResponse(
        submission: SurveyResponseSubmission,
        imageData: Data?
    ) async throws -> SurveySubmissionReceipt
    func registerDevice(token: String, timezone: String) async throws -> DeviceRegistrationResponse
}
