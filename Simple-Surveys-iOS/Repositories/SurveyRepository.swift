import Foundation

public final class SurveyRepository: SurveyRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let jsonEncoder: JSONEncoder

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    /// Fetches the specific survey configuration scheduled at the given time (e.g., prompted via notification)
    public func fetchScheduledSurvey(id: String) async throws -> SurveyConfig {
        do {
            return try await apiClient.get("/api/surveys/\(id)")
        } catch {
            #if DEBUG || targetEnvironment(simulator)
            // When running in simulator or debug mode without an active backend server,
            // fallback to a sample study survey configuration so notification prompts and survey flows can be tested end-to-end.
            return Self.sampleSurvey(forId: id)
            #else
            throw error
            #endif
        }
    }

    /// Fetches all active survey definitions stored on the backend
    public func listSurveys() async throws -> [SurveyConfig] {
        return try await apiClient.get("/api/surveys")
    }

    /// Fetches active sampling rules and notification window configuration from the backend
    public func fetchScheduleConfig() async throws -> SamplingRules {
        return try await apiClient.get("/api/notifications/schedule")
    }

    /// Submits a completed or expired survey response with optional surroundings photo
    public func submitResponse(
        submission: SurveyResponseSubmission,
        imageData: Data?
    ) async throws -> SurveySubmissionReceipt {
        do {
            if let imageData = imageData {
                let jsonData = try jsonEncoder.encode(submission)
                return try await apiClient.uploadMultipart(
                    "/api/responses",
                    jsonData: jsonData,
                    imageBytes: imageData,
                    imageFilename: "surroundings.jpg"
                )
            } else {
                return try await apiClient.post("/api/responses", body: submission)
            }
        } catch {
            #if DEBUG || targetEnvironment(simulator)
            // When offline or testing in simulator without active backend, return successful submission receipt
            return SurveySubmissionReceipt(
                responseId: submission.responseId ?? UUID().uuidString,
                surveyId: submission.surveyId,
                status: submission.answers.isEmpty ? "EXPIRED" : "COMPLETED",
                message: "Survey response recorded (local simulation mode).",
                imageStored: imageData != nil,
                imageFilename: imageData != nil ? "surroundings.jpg" : nil,
                receivedAt: Date()
            )
            #else
            throw error
            #endif
        }
    }

    /// Registers the anonymous APNs device token to receive daily scheduled survey notifications
    public func registerDevice(token: String, timezone: String) async throws -> DeviceRegistrationResponse {
        let payload = DeviceRegistration(
            deviceToken: token,
            platform: .ios,
            timezone: timezone,
            registeredAt: Date()
        )
        return try await apiClient.post("/api/notifications/devices", body: payload)
    }

    // MARK: - Sample Survey for Local / Simulator Development
    public static func sampleSurvey(forId id: String) -> SurveyConfig {
        SurveyConfig(
            surveyId: id.isEmpty ? "sample-survey-daily" : id,
            title: "Study Check-In Survey",
            description: "Please complete these brief questions about your current environment, mood, and activities.",
            notificationPrompt: NotificationPrompt(
                title: "Study Survey Window Open 🔔",
                body: "Your scheduled survey window is active. Tap here to complete your responses."
            ),
            weight: 1.0,
            isActive: true,
            questions: [
                Question(
                    questionId: "q1_energy",
                    prompt: "How energized or alert do you feel right now?",
                    type: .ratingScale,
                    isRequired: true,
                    validationRules: ValidationRules(
                        minValue: 1,
                        maxValue: 5,
                        step: 1,
                        minLabel: "1 - Exhausted",
                        maxLabel: "5 - Fully Alert"
                    )
                ),
                Question(
                    questionId: "q2_location",
                    prompt: "Where are you currently located?",
                    type: .singleChoice,
                    isRequired: true,
                    validationRules: ValidationRules(
                        options: [
                            "Home / Residence",
                            "Work / Office",
                            "Outdoors / In Transit",
                            "Cafe / Restaurant / Public Space",
                            "Other"
                        ]
                    )
                ),
                Question(
                    questionId: "q3_activity",
                    prompt: "What have you been doing over the past 30 minutes? (Select 1-3)",
                    type: .multipleChoice,
                    isRequired: true,
                    validationRules: ValidationRules(
                        options: [
                            "Working / Studying",
                            "Socializing / Talking",
                            "Eating / Drinking",
                            "Physical Exercise / Walking",
                            "Relaxing / Entertainment",
                            "Commuting / Traveling"
                        ],
                        minSelections: 1,
                        maxSelections: 3
                    )
                ),
                Question(
                    questionId: "q4_sleep",
                    prompt: "Approximately how many hours of sleep did you get last night?",
                    type: .numeric,
                    isRequired: true,
                    validationRules: ValidationRules(
                        minValue: 0,
                        maxValue: 24,
                        step: 0.5,
                        placeholder: "e.g. 7.5",
                        allowDecimals: true
                    )
                ),
                Question(
                    questionId: "q5_notes",
                    prompt: "Briefly describe your surroundings or current task:",
                    type: .text,
                    isRequired: false,
                    validationRules: ValidationRules(
                        minLength: 0,
                        maxLength: 250,
                        placeholder: "Type a brief note here (optional)..."
                    )
                )
            ]
        )
    }
}
