import Foundation

// MARK: - Sampling Mode
public enum SamplingMode: String, Codable, Sendable {
    case hybrid = "hybrid"
    case allRandom = "all_random"
    case allFixed = "all_fixed"
}

// MARK: - Time Window (HH:MM format)
public struct TimeWindow: Codable, Sendable, Equatable {
    public let startTime: String
    public let endTime: String

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
    }

    public init(startTime: String, endTime: String) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Daily Schedule Windows
public struct DailyScheduleWindows: Codable, Sendable, Equatable {
    public let overallWindow: TimeWindow
    public let firstWindow: TimeWindow
    public let lastWindow: TimeWindow

    enum CodingKeys: String, CodingKey {
        case overallWindow = "overall_window"
        case firstWindow = "first_window"
        case lastWindow = "last_window"
    }

    public init(
        overallWindow: TimeWindow,
        firstWindow: TimeWindow,
        lastWindow: TimeWindow
    ) {
        self.overallWindow = overallWindow
        self.firstWindow = firstWindow
        self.lastWindow = lastWindow
    }
}

// MARK: - Fixed Survey Config
public struct FixedSurveyConfig: Codable, Sendable, Equatable {
    public let surveyId: String
    public let position: String?            // "first", "last", or nil
    public let scheduledTime: String?        // HH:MM or nil

    enum CodingKeys: String, CodingKey {
        case surveyId = "survey_id"
        case position
        case scheduledTime = "scheduled_time"
    }

    public init(
        surveyId: String,
        position: String? = nil,
        scheduledTime: String? = nil
    ) {
        self.surveyId = surveyId
        self.position = position
        self.scheduledTime = scheduledTime
    }
}

// MARK: - Randomized Sampling Config
public struct RandomizedSamplingConfig: Codable, Sendable, Equatable {
    public let promptsPerDay: Int
    public let minIntervalMinutes: Int
    public let eligibleSurveyIds: [String]

    enum CodingKeys: String, CodingKey {
        case promptsPerDay = "prompts_per_day"
        case minIntervalMinutes = "min_interval_minutes"
        case eligibleSurveyIds = "eligible_survey_ids"
    }

    public init(
        promptsPerDay: Int = 4,
        minIntervalMinutes: Int = 90,
        eligibleSurveyIds: [String] = []
    ) {
        self.promptsPerDay = promptsPerDay
        self.minIntervalMinutes = minIntervalMinutes
        self.eligibleSurveyIds = eligibleSurveyIds
    }
}

// MARK: - Complete Sampling Rules
public struct SamplingRules: Codable, Sendable, Equatable {
    public let mode: SamplingMode
    public let timeToCompleteMinutes: Int
    public let dailySchedule: DailyScheduleWindows
    public let fixedSurveys: [FixedSurveyConfig]
    public let randomizedSampling: RandomizedSamplingConfig

    enum CodingKeys: String, CodingKey {
        case mode
        case timeToCompleteMinutes = "time_to_complete_minutes"
        case dailySchedule = "daily_schedule"
        case fixedSurveys = "fixed_surveys"
        case randomizedSampling = "randomized_sampling"
    }

    public init(
        mode: SamplingMode = .hybrid,
        timeToCompleteMinutes: Int = 5,
        dailySchedule: DailyScheduleWindows,
        fixedSurveys: [FixedSurveyConfig] = [],
        randomizedSampling: RandomizedSamplingConfig
    ) {
        self.mode = mode
        self.timeToCompleteMinutes = timeToCompleteMinutes
        self.dailySchedule = dailySchedule
        self.fixedSurveys = fixedSurveys
        self.randomizedSampling = randomizedSampling
    }
}

// MARK: - Planned Scheduled Dispatch Model
public struct ScheduledDispatchInfo: Identifiable, Sendable, Equatable {
    public var id: String { "\(surveyId)_\(dispatchTime.timeIntervalSince1970)" }
    public let surveyId: String
    public let dispatchTime: Date
    public let isFixed: Bool
    public let position: String?
    public let promptTitle: String
    public let promptBody: String

    public init(
        surveyId: String,
        dispatchTime: Date,
        isFixed: Bool,
        position: String? = nil,
        promptTitle: String = "Survey Check-In",
        promptBody: String = "Time for your scheduled survey prompt. Please tap to respond."
    ) {
        self.surveyId = surveyId
        self.dispatchTime = dispatchTime
        self.isFixed = isFixed
        self.position = position
        self.promptTitle = promptTitle
        self.promptBody = promptBody
    }
}
