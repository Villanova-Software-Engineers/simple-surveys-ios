import SwiftUI
import Observation

@Observable
public final class HomeViewModel {
    public var activeSurvey: SurveyConfig?
    public var activeSurveyViewModel: SurveyViewModel?
    public var notificationSentAt: Date?
    public var timeToCompleteMinutes: Int = AppConfiguration.defaultTimeToCompleteMinutes
    public var isLoading: Bool = false
    public var isSyncingSchedule: Bool = false
    public var errorMessage: String?
    public var statusBanner: String?
    public var arePermissionsValid: Bool = true
    public var shouldOpenSurveySheet: Bool = false
    public var currentSurveyViewModel: SurveyViewModel?
    public var showingLegalSheet: Bool = false
    public var activeLegalTab: LegalTab = .terms

    // Scheduling state
    public var samplingRules: SamplingRules?
    public var todayDispatches: [ScheduledDispatchInfo] = []
    public var nextPrompt: ScheduledDispatchInfo?

    // Active window live countdown on Home dashboard
    public var activeWindowRemainingSeconds: Int = 0
    private var windowCountdownTask: Task<Void, Never>?

    private let repository: SurveyRepositoryProtocol
    private let permissionManager: PermissionManagerProtocol
    private let locationService: LocationServiceProtocol

    public init(
        repository: SurveyRepositoryProtocol,
        permissionManager: PermissionManagerProtocol,
        locationService: LocationServiceProtocol
    ) {
        self.repository = repository
        self.permissionManager = permissionManager
        self.locationService = locationService
    }

    public func checkPermissions() async {
        let valid = await permissionManager.checkPermissionStatus()
        await MainActor.run {
            self.arePermissionsValid = valid
        }
    }

    /// Synchronizes sampling rules from the backend (GET /api/notifications/schedule)
    public func syncScheduleAndPrompts() async {
        isSyncingSchedule = true
        errorMessage = nil

        do {
            let rules = try await repository.fetchScheduleConfig()

            await MainActor.run {
                self.samplingRules = rules
                self.timeToCompleteMinutes = rules.timeToCompleteMinutes
                self.isSyncingSchedule = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Schedule not synced with server."
                self.isSyncingSchedule = false
            }
        }
    }

    /// Simulates receiving an APNs prompt for a test survey (fetched directly from backend)
    public func simulateSurveyNotification(surveyId: String) async {
        await handleIncomingSurveyPrompt(
            surveyId: surveyId,
            sentAt: Date(),
            autoOpen: true
        )
    }

    /// Handles an incoming survey prompt from APNs banner or notification tap
    public func handleIncomingSurveyPrompt(
        surveyId: String,
        sentAt: Date?,
        timeToComplete: Int? = nil,
        autoOpen: Bool = false
    ) async {
        isLoading = true
        errorMessage = nil
        let promptSentAt = sentAt ?? Date()
        self.notificationSentAt = promptSentAt
        if let limit = timeToComplete {
            self.timeToCompleteMinutes = limit
        }

        do {
            let survey = try await repository.fetchScheduledSurvey(id: surveyId)
            await MainActor.run {
                self.activeSurvey = survey
                self.activeSurveyViewModel = SurveyViewModel(
                    survey: survey,
                    notificationSentAt: self.notificationSentAt,
                    timeToCompleteMinutes: AppConfiguration.defaultTimeToCompleteMinutes,
                    repository: self.repository,
                    locationService: self.locationService
                )
                self.isLoading = false
                self.startActiveWindowCountdown(sentAt: promptSentAt, limitMinutes: self.timeToCompleteMinutes)
                if autoOpen {
                    self.startActiveSurvey()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load scheduled survey: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    public func startActiveSurvey() {
        guard let survey = activeSurvey else { return }
        if currentSurveyViewModel == nil || currentSurveyViewModel?.survey.surveyId != survey.surveyId {
            let vm = SurveyViewModel(
                survey: survey,
                notificationSentAt: notificationSentAt,
                timeToCompleteMinutes: timeToCompleteMinutes,
                repository: repository,
                locationService: locationService
            )
            vm.onSubmissionCompleted = { [weak self] in
                self?.handleSurveyCompleted()
            }
            self.currentSurveyViewModel = vm
        }
        self.shouldOpenSurveySheet = true
    }

    public func handleSurveyCompleted() {
        self.activeSurvey = nil
        self.notificationSentAt = nil
        self.windowCountdownTask?.cancel()
        self.activeWindowRemainingSeconds = 0
        self.statusBanner = "Survey submitted successfully. Thank you!"
        self.updateNextPrompt()
    }

    public func dismissSurvey() {
        if currentSurveyViewModel?.submissionCompleted == true || currentSurveyViewModel?.isExpired == true {
            handleSurveyCompleted()
        }
        self.shouldOpenSurveySheet = false
        self.currentSurveyViewModel = nil
    }

    public func clearActiveSurvey() {
        self.activeSurvey = nil
        self.activeSurveyViewModel = nil
        self.notificationSentAt = nil
        self.dismissSurvey()
        self.windowCountdownTask?.cancel()
        self.activeWindowRemainingSeconds = 0
        updateNextPrompt()
    }

    public func openLegalDocument(_ tab: LegalTab) {
        self.activeLegalTab = tab
        self.showingLegalSheet = true
    }

    // MARK: - Private Helpers

    private func updateNextPrompt() {
        let now = Date()
        self.nextPrompt = todayDispatches.first(where: { $0.dispatchTime > now })
    }

    private func startActiveWindowCountdown(sentAt: Date, limitMinutes: Int) {
        windowCountdownTask?.cancel()
        let deadline = sentAt.addingTimeInterval(Double(limitMinutes * 60))
        let remaining = Int(deadline.timeIntervalSince(Date()))
        self.activeWindowRemainingSeconds = max(0, remaining)

        windowCountdownTask = Task { @MainActor in
            while activeWindowRemainingSeconds > 0 && activeSurvey != nil {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                activeWindowRemainingSeconds -= 1
            }
        }
    }

    deinit {
        windowCountdownTask?.cancel()
    }
}
