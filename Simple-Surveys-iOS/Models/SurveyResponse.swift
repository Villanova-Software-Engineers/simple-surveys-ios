import Foundation

// MARK: - Ingress Submission Payload (Client -> Server)

public struct SurveyResponseSubmission: Codable, Sendable {
    public let responseId: String?
    public let surveyId: String
    public let notificationSentAt: Date?
    public let startedAt: Date
    public let completedAt: Date
    public let location: LocationData?
    public let answers: [QuestionAnswer]
    public let parentResponseId: String?
    public let researcherMessage: String?

    enum CodingKeys: String, CodingKey {
        case responseId = "response_id"
        case surveyId = "survey_id"
        case notificationSentAt = "notification_sent_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case location
        case answers
        case parentResponseId = "parent_response_id"
        case researcherMessage = "researcher_message"
    }

    public init(
        responseId: String? = nil,
        surveyId: String,
        notificationSentAt: Date? = nil,
        startedAt: Date,
        completedAt: Date,
        location: LocationData? = nil,
        answers: [QuestionAnswer],
        parentResponseId: String? = nil,
        researcherMessage: String? = nil
    ) {
        self.responseId = responseId
        self.surveyId = surveyId
        self.notificationSentAt = notificationSentAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.location = location
        self.answers = answers
        self.parentResponseId = parentResponseId
        self.researcherMessage = researcherMessage
    }
}

public typealias SurveyResponseCreate = SurveyResponseSubmission

public struct QuestionAnswer: Codable, Sendable {
    public let questionId: String
    public let questionPrompt: String
    public let value: AnyCodableValue

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case questionPrompt = "question_prompt"
        case value
    }

    public init(
        questionId: String,
        questionPrompt: String = "",
        value: AnyCodableValue
    ) {
        self.questionId = questionId
        self.questionPrompt = questionPrompt
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.questionId = try container.decode(String.self, forKey: .questionId)
        self.questionPrompt = try container.decodeIfPresent(String.self, forKey: .questionPrompt) ?? ""
        self.value = try container.decode(AnyCodableValue.self, forKey: .value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(questionId, forKey: .questionId)
        try container.encode(questionPrompt, forKey: .questionPrompt)
        try container.encode(value, forKey: .value)
    }
}

public typealias AnswerItem = QuestionAnswer

// MARK: - Follow-Up Survey Payload (Server -> Client)

public struct FollowUpSurveyPayload: Codable, Sendable, Identifiable {
    public var id: String { "\(surveyId)_\(roundNumber)_\(parentResponseId)" }
    public let parentResponseId: String
    public let surveyId: String
    public let roundNumber: Int
    public let title: String
    public let researcherMessage: String?
    public let questions: [Question]

    enum CodingKeys: String, CodingKey {
        case parentResponseId = "parent_response_id"
        case surveyId = "survey_id"
        case roundNumber = "round_number"
        case title
        case researcherMessage = "researcher_message"
        case questions
    }

    public init(
        parentResponseId: String,
        surveyId: String,
        roundNumber: Int = 1,
        title: String = "Follow-up Questions",
        researcherMessage: String? = nil,
        questions: [Question] = []
    ) {
        self.parentResponseId = parentResponseId
        self.surveyId = surveyId
        self.roundNumber = roundNumber
        self.title = title
        self.researcherMessage = researcherMessage
        self.questions = questions
    }
}

// MARK: - Server Response Receipt

public struct SurveySubmissionReceipt: Codable, Sendable {
    public let responseId: String
    public let surveyId: String
    public let status: String           // "COMPLETED" or "EXPIRED"
    public let statusMessage: String?
    public let message: String?
    public let imageStored: Bool
    public let imageFilename: String?
    public let receivedAt: Date?
    public let followupSurvey: FollowUpSurveyPayload?

    enum CodingKeys: String, CodingKey {
        case responseId = "response_id"
        case surveyId = "survey_id"
        case status
        case statusMessage = "status_message"
        case message
        case imageStored = "image_stored"
        case imageFilename = "image_filename"
        case receivedAt = "received_at"
        case followupSurvey = "followup_survey"
    }

    public init(
        responseId: String,
        surveyId: String,
        status: String,
        statusMessage: String? = nil,
        message: String? = nil,
        imageStored: Bool = false,
        imageFilename: String? = nil,
        receivedAt: Date? = Date(),
        followupSurvey: FollowUpSurveyPayload? = nil
    ) {
        self.responseId = responseId
        self.surveyId = surveyId
        self.status = status
        self.statusMessage = statusMessage
        self.message = message
        self.imageStored = imageStored
        self.imageFilename = imageFilename
        self.receivedAt = receivedAt
        self.followupSurvey = followupSurvey
    }
}

public typealias SurveyResponseSubmissionResult = SurveySubmissionReceipt
