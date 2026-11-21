import Foundation

// MARK: - Adaptive Follow-Up Configuration

public struct AdaptiveFollowUpConfig: Codable, Sendable {
    public let enabled: Bool
    public let maxQuestionsPerRound: Int
    public let maxFollowupRounds: Int
    public let researcherPrompt: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case maxQuestionsPerRound = "max_questions_per_round"
        case maxFollowupRounds = "max_followup_rounds"
        case researcherPrompt = "researcher_prompt"
    }

    public init(
        enabled: Bool = true,
        maxQuestionsPerRound: Int = 2,
        maxFollowupRounds: Int = 1,
        researcherPrompt: String? = nil
    ) {
        self.enabled = enabled
        self.maxQuestionsPerRound = maxQuestionsPerRound
        self.maxFollowupRounds = maxFollowupRounds
        self.researcherPrompt = researcherPrompt
    }
}

// MARK: - Survey Configuration

public struct SurveyConfig: Codable, Identifiable, Sendable {
    public var id: String { surveyId }
    public let surveyId: String
    public let title: String
    public let description: String?
    public let notificationPrompt: NotificationPrompt?
    public let weight: Double
    public let isActive: Bool
    public let questions: [Question]
    public let adaptiveFollowup: AdaptiveFollowUpConfig?

    enum CodingKeys: String, CodingKey {
        case surveyId = "survey_id"
        case title
        case description
        case notificationPrompt = "notification_prompt"
        case weight
        case isActive = "is_active"
        case questions
        case adaptiveFollowup = "adaptive_followup"
    }

    public init(
        surveyId: String,
        title: String,
        description: String? = nil,
        notificationPrompt: NotificationPrompt? = nil,
        weight: Double = 1.0,
        isActive: Bool = true,
        questions: [Question] = [],
        adaptiveFollowup: AdaptiveFollowUpConfig? = nil
    ) {
        self.surveyId = surveyId
        self.title = title
        self.description = description
        self.notificationPrompt = notificationPrompt
        self.weight = weight
        self.isActive = isActive
        self.questions = questions
        self.adaptiveFollowup = adaptiveFollowup
    }
}

public struct NotificationPrompt: Codable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}
