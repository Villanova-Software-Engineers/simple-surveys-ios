import SwiftUI
import Observation

@Observable
public final class SurveyViewModel: Identifiable {
    public var id: String { survey.surveyId }

    // State
    public var survey: SurveyConfig
    public var answers: [String: AnyCodableValue] = [:]
    public var capturedImage: CapturedImage?
    public var isSubmitting: Bool = false
    public var isExpired: Bool = false
    public var remainingSeconds: Int = 0
    public var errorMessage: String?
    public var submissionCompleted: Bool = false
    @ObservationIgnored public var onSubmissionCompleted: (() -> Void)?

    private let notificationSentAt: Date?
    private let startedAt: Date
    private let timeToCompleteMinutes: Int
    private var timerTask: Task<Void, Never>?

    private let repository: SurveyRepositoryProtocol
    private let locationService: LocationServiceProtocol

    public init(
        survey: SurveyConfig,
        notificationSentAt: Date?,
        timeToCompleteMinutes: Int = 5,
        repository: SurveyRepositoryProtocol,
        locationService: LocationServiceProtocol
    ) {
        self.survey = survey
        self.notificationSentAt = notificationSentAt
        self.startedAt = Date()
        self.timeToCompleteMinutes = timeToCompleteMinutes
        self.repository = repository
        self.locationService = locationService

        calculateInitialRemainingTime()
        if isExpired {
            handleExpiration()
        } else {
            startCountdownTimer()
        }
    }

    private func calculateInitialRemainingTime() {
        let referenceDate = notificationSentAt ?? startedAt
        let deadline = referenceDate.addingTimeInterval(Double(timeToCompleteMinutes * 60))
        let remaining = Int(deadline.timeIntervalSince(Date()))
        self.remainingSeconds = max(0, remaining)
        if self.remainingSeconds <= 0 {
            self.isExpired = true
            handleExpiration()
        }
    }

    private func startCountdownTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while remainingSeconds > 0 && !isExpired && !submissionCompleted {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remainingSeconds -= 1
                if remainingSeconds <= 0 {
                    isExpired = true
                    handleExpiration()
                }
            }
        }
    }

    private func handleExpiration() {
        // Automatically submit expired audit record with empty answers
        Task {
            await submitResponse(isForcedExpired: true)
        }
    }

    public func submitResponse(isForcedExpired: Bool = false) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        // Validate required questions and constraints if not expired
        if !isForcedExpired && !isExpired {
            for question in survey.questions {
                if question.isRequired {
                    guard let answer = answers[question.questionId] else {
                        errorMessage = "Please answer all required questions before submitting."
                        isSubmitting = false
                        return
                    }
                    if case .null = answer {
                        errorMessage = "Please answer all required questions before submitting."
                        isSubmitting = false
                        return
                    }
                    if case .string(let str) = answer, str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errorMessage = "Please answer all required questions before submitting."
                        isSubmitting = false
                        return
                    }
                    if case .stringArray(let arr) = answer, arr.isEmpty {
                        errorMessage = "Please select at least one option for \"\(question.prompt)\"."
                        isSubmitting = false
                        return
                    }
                }

                // Multiple choice min/max constraints
                if case .stringArray(let arr) = answers[question.questionId] {
                    if let minSel = question.validationRules?.minSelections, arr.count < minSel {
                        errorMessage = "Please select at least \(minSel) options for \"\(question.prompt)\"."
                        isSubmitting = false
                        return
                    }
                    if let maxSel = question.validationRules?.maxSelections, arr.count > maxSel {
                        errorMessage = "Please select at most \(maxSel) options for \"\(question.prompt)\"."
                        isSubmitting = false
                        return
                    }
                }

                // Text length min/max constraints
                if case .string(let str) = answers[question.questionId] {
                    if let minLen = question.validationRules?.minLength, str.count < minLen {
                        errorMessage = "Answer for \"\(question.prompt)\" must be at least \(minLen) characters."
                        isSubmitting = false
                        return
                    }
                }
            }
        }

        let location = await locationService.getCurrentLocation()
        let completedAt = Date()

        // Per backend plan: if expired, answers must be autofilled empty []
        let answersPayload: [QuestionAnswer]
        if isForcedExpired || isExpired {
            answersPayload = []
        } else {
            answersPayload = survey.questions.compactMap { q in
                guard let val = answers[q.questionId] else { return nil }
                return QuestionAnswer(questionId: q.questionId, value: val)
            }
        }

        let submission = SurveyResponseSubmission(
            responseId: nil,
            surveyId: survey.surveyId,
            notificationSentAt: notificationSentAt,
            startedAt: startedAt,
            completedAt: completedAt,
            location: location,
            answers: answersPayload
        )

        do {
            _ = try await repository.submitResponse(
                submission: submission,
                imageData: capturedImage?.data
            )
            await MainActor.run {
                self.submissionCompleted = true
                self.timerTask?.cancel()
                self.onSubmissionCompleted?()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isSubmitting = false
        }
    }

    deinit {
        timerTask?.cancel()
    }
}
