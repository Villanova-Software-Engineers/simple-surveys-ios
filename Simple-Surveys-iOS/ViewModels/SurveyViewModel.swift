import SwiftUI
import Observation

@Observable
public final class SurveyViewModel: Identifiable {
    public var id: String { survey.surveyId }

    // State
    public var survey: SurveyConfig
    public var answers: [String: AnyCodableValue] = [:]
    public var gatingVisibilityMap: [String: Bool] = [:]
    public var gatingScores: [String: GatingEvaluationScore] = [:]
    public var capturedImage: CapturedImage?
    public var isSubmitting: Bool = false
    public var isExpired: Bool = false
    public var remainingSeconds: Int = 0
    public var timeRemainingSeconds: Int {
        get { remainingSeconds }
        set { remainingSeconds = newValue }
    }
    public var errorMessage: String?
    public var submissionCompleted: Bool = false
    @ObservationIgnored public var onSubmissionCompleted: (() -> Void)?

    // Adaptive Follow-Up State
    public var activeFollowUp: FollowUpSurveyPayload? = nil
    public var isFollowUpRound: Bool { activeFollowUp != nil }
    public var currentQuestions: [Question] { activeFollowUp?.questions ?? survey.questions }
    public var currentTitle: String { activeFollowUp?.title ?? survey.title }
    public var researcherMessage: String? { activeFollowUp?.researcherMessage }
    public private(set) var initialResponseId: String? = nil
    public private(set) var parentResponseId: String? = nil

    // Independent Timers & Lifecycles
    public private(set) var notificationSentAt: Date?
    public private(set) var startedAt: Date
    public private(set) var initialNotificationSentAt: Date?
    public private(set) var roundPresentedAt: Date?
    public private(set) var followupReceivedAt: Date?
    public private(set) var roundStartedAt: Date?
    public private(set) var initialCompletedAt: Date?
    public private(set) var roundCompletedAt: Date?

    private let timeToCompleteMinutes: Int
    private var timerTask: Task<Void, Never>?
    private var gatingDebounceTask: Task<Void, Never>?

    private let repository: SurveyRepositoryProtocol
    private let locationService: LocationServiceProtocol
    private let gatingService: OnDeviceGatingServiceProtocol

    public init(
        survey: SurveyConfig,
        notificationSentAt: Date?,
        timeToCompleteMinutes: Int = 5,
        repository: SurveyRepositoryProtocol,
        locationService: LocationServiceProtocol,
        gatingService: OnDeviceGatingServiceProtocol = OnDeviceGatingService.shared
    ) {
        let now = Date()
        self.survey = survey
        self.notificationSentAt = notificationSentAt
        self.initialNotificationSentAt = notificationSentAt
        self.startedAt = now
        self.roundPresentedAt = now
        self.timeToCompleteMinutes = timeToCompleteMinutes
        self.repository = repository
        self.locationService = locationService
        self.gatingService = gatingService

        // Initialize question gating visibility map
        initializeGatingVisibility(for: survey.questions)

        calculateInitialRemainingTime()
        if isExpired {
            handleExpiration()
        } else {
            startCountdownTimer()
        }
    }

    private func initializeGatingVisibility(for questions: [Question]) {
        var map: [String: Bool] = [:]
        for q in questions {
            if q.gatingRule == nil {
                map[q.questionId] = true
            } else {
                map[q.questionId] = false
            }
        }
        self.gatingVisibilityMap = map
    }

    /// Records user interaction to timestamp started_at for follow-up rounds.
    public func recordInteraction() {
        if isFollowUpRound && roundStartedAt == nil {
            roundStartedAt = Date()
        }
    }

    // MARK: - On-Device Semantic Gating Evaluation & Debounced Inactivity Delay

    /// Called when user edits a text input.
    /// Debounces for 600ms of typing inactivity before evaluating OpenJev, eliminating mid-typing flicker.
    public func handleTextChanged(questionId: String, newText: String) {
        recordInteraction()

        // 1. Cancel previous pending task immediately on each new keystroke
        gatingDebounceTask?.cancel()

        gatingDebounceTask = Task { @MainActor [weak self] in
            // 2. Wait for typing inactivity pause (600ms of typing silence)
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled, let self = self else { return }

            // 3. OpenJev Guards: Check minimum word count (at least 3 words)
            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
            let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count

            guard wordCount >= 3 else {
                await self.updateGatedQuestions(sourceQuestionId: questionId, isVisible: false)
                return
            }

            // 4. Run OpenJev once on the complete paused thought
            await self.evaluateGatesForQuestion(questionId: questionId, text: trimmed)
        }
    }

    /// Called on field blur (keyboard dismiss / user taps outside / focus lost) to bypass delay and evaluate immediately.
    public func handleTextFieldBlur(questionId: String, currentText: String) {
        recordInteraction()
        gatingDebounceTask?.cancel()
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count

        guard wordCount >= 3 else {
            Task { @MainActor [weak self] in
                await self?.updateGatedQuestions(sourceQuestionId: questionId, isVisible: false)
            }
            return
        }

        Task { @MainActor [weak self] in
            await self?.evaluateGatesForQuestion(questionId: questionId, text: trimmed)
        }
    }

    /// Updates visibility and scores for all questions dependent on a specific source question.
    public func updateGatedQuestions(sourceQuestionId: String, isVisible: Bool) async {
        var updatedMap = gatingVisibilityMap
        var updatedScores = gatingScores

        for q in currentQuestions {
            if let rule = q.gatingRule, rule.sourceQuestionId == sourceQuestionId {
                updatedMap[q.questionId] = isVisible
                if !isVisible {
                    updatedScores[sourceQuestionId] = GatingEvaluationScore(
                        score: 0.0,
                        threshold: rule.threshold,
                        matched: false,
                        condition: rule.naturalLanguageCondition ?? ""
                    )
                }
            }
        }

        await MainActor.run {
            self.gatingVisibilityMap = updatedMap
            self.gatingScores = updatedScores
        }
    }

    /// Evaluates rules for questions dependent on a specific source question with the given text.
    public func evaluateGatesForQuestion(questionId: String, text: String) async {
        var updatedMap = gatingVisibilityMap
        var updatedScores = gatingScores

        for q in currentQuestions {
            if let rule = q.gatingRule, rule.sourceQuestionId == questionId {
                let scoreResult = await gatingService.evaluateRuleWithScore(
                    rule: rule,
                    answer: .string(text)
                )
                updatedMap[q.questionId] = scoreResult.matched
                updatedScores[rule.sourceQuestionId] = scoreResult
            }
        }

        await MainActor.run {
            self.gatingVisibilityMap = updatedMap
            self.gatingScores = updatedScores
        }
    }

    /// Evaluates all gating rules in current active question set.
    public func evaluateAllGatingRules() async {
        let questions = currentQuestions
        var updatedMap = gatingVisibilityMap
        var updatedScores = gatingScores

        for q in questions {
            if let rule = q.gatingRule {
                let sourceAnswer = answers[rule.sourceQuestionId]

                // Guard for text-based OpenJev rules: require at least 3 words
                if rule.operator == .openjevMatches {
                    let text = sourceAnswer?.stringValue ?? ""
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
                    if wordCount < 3 {
                        updatedMap[q.questionId] = false
                        updatedScores[rule.sourceQuestionId] = GatingEvaluationScore(
                            score: 0.0,
                            threshold: rule.threshold,
                            matched: false,
                            condition: rule.naturalLanguageCondition ?? ""
                        )
                        continue
                    }
                }

                let scoreResult = await gatingService.evaluateRuleWithScore(rule: rule, answer: sourceAnswer)
                updatedMap[q.questionId] = scoreResult.matched
                updatedScores[rule.sourceQuestionId] = scoreResult
            } else {
                updatedMap[q.questionId] = true
            }
        }

        await MainActor.run {
            self.gatingVisibilityMap = updatedMap
            self.gatingScores = updatedScores
        }
    }

    /// Pre-submission instant barrier: validates all gates with current inputs so the user
    /// cannot accidentally bypass a newly satisfied gate.
    private func preSubmissionGateCheck() async -> Bool {
        let previousMap = gatingVisibilityMap
        await evaluateAllGatingRules()

        for q in currentQuestions {
            let wasVisible = previousMap[q.questionId] ?? (q.gatingRule == nil)
            let isNowVisible = gatingVisibilityMap[q.questionId] ?? true
            if !wasVisible && isNowVisible {
                let answer = answers[q.questionId]
                if answer == nil || answer?.isEmpty == true {
                    errorMessage = "A newly revealed question requires your response before submission."
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Independent Survey Timer Control

    /// Starts or restarts the countdown timer for the specified duration.
    public func startTimer(durationMinutes: Int = 5) {
        stopTimer()
        self.remainingSeconds = durationMinutes * 60
        self.isExpired = false
        self.roundPresentedAt = Date()
        startCountdownTimer()
    }

    /// Freezes the countdown timer immediately.
    public func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
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
        timerTask = Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self = self else { return }
                guard self.remainingSeconds > 0 && !self.isExpired && !self.submissionCompleted else { return }

                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.isExpired = true
                    self.stopTimer()
                    self.handleExpiration()
                    return
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

    // MARK: - Validation

    private func validateVisibleQuestions() -> Bool {
        for question in currentQuestions {
            // Only validate questions that are currently visible
            let isVisible = gatingVisibilityMap[question.questionId] ?? (question.gatingRule == nil)
            guard isVisible else { continue }

            if question.isRequired {
                guard let answer = answers[question.questionId] else {
                    errorMessage = "Please answer all required questions before submitting."
                    return false
                }
                if answer.isEmpty {
                    errorMessage = "Please answer all required questions before submitting."
                    return false
                }
            }

            // Multiple choice min/max constraints
            if case .stringArray(let arr) = answers[question.questionId] {
                if let minSel = question.validationRules?.minSelections, arr.count < minSel {
                    errorMessage = "Please select at least \(minSel) options for \"\(question.prompt)\"."
                    return false
                }
                if let maxSel = question.validationRules?.maxSelections, arr.count > maxSel {
                    errorMessage = "Please select at most \(maxSel) options for \"\(question.prompt)\"."
                    return false
                }
            }

            // Text length min/max constraints
            if case .string(let str) = answers[question.questionId] {
                if let minLen = question.validationRules?.minLength, str.count < minLen {
                    errorMessage = "Answer for \"\(question.prompt)\" must be at least \(minLen) characters."
                    return false
                }
            }

            // Numeric min/max constraints
            if question.type == .numeric {
                if let answer = answers[question.questionId], let val = answer.doubleValue {
                    if let max = question.validationRules?.maxValue, val > max {
                        let maxStr = max.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(max)) : String(max)
                        errorMessage = "Answer for \"\(question.prompt)\" cannot exceed \(maxStr)."
                        return false
                    }
                    if let min = question.validationRules?.minValue, val < min {
                        let minStr = min.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(min)) : String(min)
                        errorMessage = "Answer for \"\(question.prompt)\" must be at least \(minStr)."
                        return false
                    }
                }
            }
        }
        return true
    }

    // MARK: - Survey Submission

    /// Submits either the initial intake or the follow-up survey based on active round.
    public func submitResponse(isForcedExpired: Bool = false) async {
        if isFollowUpRound {
            await submitFollowUpSurvey(isForcedExpired: isForcedExpired)
        } else {
            await submitInitialSurvey(isForcedExpired: isForcedExpired)
        }
    }

    /// Submits initial survey answers with question prompts always attached and freezes the timer immediately.
    public func submitInitialSurvey(isForcedExpired: Bool = false) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        // FREEZE TIMER IMMEDIATELY on submit tap
        stopTimer()
        let completedAt = Date()
        self.initialCompletedAt = completedAt

        if !isForcedExpired && !isExpired {
            let barrierPassed = await preSubmissionGateCheck()
            guard barrierPassed else {
                isSubmitting = false
                if remainingSeconds > 0 { startCountdownTimer() }
                return
            }

            guard validateVisibleQuestions() else {
                isSubmitting = false
                if remainingSeconds > 0 { startCountdownTimer() }
                return
            }
        }

        let location = await locationService.getCurrentLocation()

        // Construct answers ALWAYS attaching question prompt
        let answersPayload: [QuestionAnswer]
        if isForcedExpired || isExpired {
            answersPayload = []
        } else {
            answersPayload = survey.questions.compactMap { q in
                let isVisible = gatingVisibilityMap[q.questionId] ?? (q.gatingRule == nil)
                guard isVisible, let val = answers[q.questionId] else { return nil }
                return QuestionAnswer(
                    questionId: q.questionId,
                    questionPrompt: q.prompt,
                    value: val
                )
            }
        }

        let submission = SurveyResponseSubmission(
            responseId: nil,
            surveyId: survey.surveyId,
            notificationSentAt: initialNotificationSentAt ?? notificationSentAt,
            startedAt: startedAt,
            completedAt: completedAt,
            location: location,
            answers: answersPayload,
            parentResponseId: nil,
            researcherMessage: nil
        )

        do {
            let receipt = try await repository.submitResponse(
                submission: submission,
                imageData: capturedImage?.data
            )
            let receivedAt = Date()

            await MainActor.run {
                if receipt.status != "EXPIRED", let followUp = receipt.followupSurvey, !followUp.questions.isEmpty {
                    // Transition to adaptive follow-up round with a fresh timer
                    self.transitionToFollowUpRound(followUp, parentResponseId: receipt.responseId, receivedAt: receivedAt)
                } else {
                    // Final survey completion (or expired)
                    self.activeFollowUp = nil
                    self.submissionCompleted = true
                    self.stopTimer()
                    self.onSubmissionCompleted?()
                    self.isSubmitting = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isSubmitting = false
                if self.remainingSeconds > 0 {
                    self.startCountdownTimer()
                }
            }
        }
    }

    /// Transitions to follow-up round and resets a fresh 5-minute timer.
    private func transitionToFollowUpRound(_ followup: FollowUpSurveyPayload, parentResponseId: String, receivedAt: Date = Date()) {
        if self.initialResponseId == nil {
            self.initialResponseId = parentResponseId
        }
        self.parentResponseId = parentResponseId
        self.activeFollowUp = followup
        self.followupReceivedAt = receivedAt
        self.notificationSentAt = receivedAt
        self.roundPresentedAt = Date()
        self.roundStartedAt = nil
        self.answers.removeAll()
        self.initializeGatingVisibility(for: followup.questions)
        self.isSubmitting = false

        // START BRAND NEW COUNTDOWN TIMER FOR FOLLOW-UP ROUND
        startTimer(durationMinutes: 5)
    }

    /// Submits follow-up survey answers with question prompts always attached and passes fresh notification_sent_at and started_at.
    public func submitFollowUpSurvey(isForcedExpired: Bool = false) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        // FREEZE TIMER IMMEDIATELY on submit tap
        stopTimer()
        let completedAt = Date()
        self.roundCompletedAt = completedAt

        if !isForcedExpired && !isExpired {
            let barrierPassed = await preSubmissionGateCheck()
            guard barrierPassed else {
                isSubmitting = false
                if remainingSeconds > 0 { startCountdownTimer() }
                return
            }

            guard validateVisibleQuestions() else {
                isSubmitting = false
                if remainingSeconds > 0 { startCountdownTimer() }
                return
            }
        }

        guard let followUp = activeFollowUp else {
            isSubmitting = false
            return
        }

        let location = await locationService.getCurrentLocation()

        // Construct follow-up answers ALWAYS attaching question prompt
        let answersPayload: [QuestionAnswer]
        if isForcedExpired || isExpired {
            answersPayload = []
        } else {
            answersPayload = followUp.questions.compactMap { q in
                let isVisible = gatingVisibilityMap[q.questionId] ?? (q.gatingRule == nil)
                guard isVisible, let val = answers[q.questionId] else { return nil }
                return QuestionAnswer(
                    questionId: q.questionId,
                    questionPrompt: q.prompt,
                    value: val
                )
            }
        }

        let sentAt = followupReceivedAt ?? roundPresentedAt ?? Date()
        let started = roundStartedAt ?? roundPresentedAt ?? sentAt
        let parentId = parentResponseId ?? (followUp.parentResponseId.isEmpty ? initialResponseId : followUp.parentResponseId)

        let submission = SurveyResponseSubmission(
            responseId: nil,
            surveyId: followUp.surveyId,
            notificationSentAt: sentAt,
            startedAt: started,
            completedAt: completedAt,
            location: location,
            answers: answersPayload,
            parentResponseId: parentId,
            researcherMessage: followUp.researcherMessage
        )

        do {
            let receipt = try await repository.submitResponse(
                submission: submission,
                imageData: nil
            )
            let receivedAt = Date()

            await MainActor.run {
                if receipt.status != "EXPIRED", let nextFollowUp = receipt.followupSurvey, !nextFollowUp.questions.isEmpty {
                    // Transition to next follow-up round (e.g. Round 2, Round 3)
                    self.transitionToFollowUpRound(nextFollowUp, parentResponseId: receipt.responseId, receivedAt: receivedAt)
                } else {
                    // Final survey completion (or expired)
                    self.activeFollowUp = nil
                    self.submissionCompleted = true
                    self.stopTimer()
                    self.onSubmissionCompleted?()
                    self.isSubmitting = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isSubmitting = false
                if self.remainingSeconds > 0 {
                    self.startCountdownTimer()
                }
            }
        }
    }

    /// Allows participants to gracefully exit during follow-up round without losing their initial submission.
    public func skipFollowUp() {
        guard isFollowUpRound else { return }
        self.stopTimer()
        self.activeFollowUp = nil
        self.submissionCompleted = true
        self.onSubmissionCompleted?()
    }

    deinit {
        timerTask?.cancel()
        gatingDebounceTask?.cancel()
    }
}
