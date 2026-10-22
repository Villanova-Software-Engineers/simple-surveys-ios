import SwiftUI
import Observation

@Observable
public final class HomeViewModel {
    public var activeSurvey: SurveyConfig?
    public var activeSurveyViewModel: SurveyViewModel?
    public var notificationSentAt: Date?
    public var isLoading: Bool = false
    public var errorMessage: String?
    public var arePermissionsValid: Bool = true
    public var isSurveyPresented: Bool = false
    public var showingLegalSheet: Bool = false
    public var activeLegalTab: LegalTab = .terms

    private let repository: SurveyRepositoryProtocol
    private let locationService: LocationServiceProtocol
    private let permissionManager: PermissionManagerProtocol

    public init(
        repository: SurveyRepositoryProtocol,
        locationService: LocationServiceProtocol = LocationService(),
        permissionManager: PermissionManagerProtocol
    ) {
        self.repository = repository
        self.locationService = locationService
        self.permissionManager = permissionManager
    }

    public func checkPermissions() async {
        let valid = await permissionManager.checkPermissionStatus()
        await MainActor.run {
            self.arePermissionsValid = valid
        }
    }

    public func handleIncomingSurveyPrompt(surveyId: String, sentAt: Date?) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.notificationSentAt = sentAt ?? Date()
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
                self.isSurveyPresented = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load scheduled survey: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    public func ensureSurveyViewModel(repository: SurveyRepositoryProtocol, locationService: LocationServiceProtocol) -> SurveyViewModel? {
        if let existing = activeSurveyViewModel {
            return existing
        }
        guard let survey = activeSurvey else { return nil }
        let vm = SurveyViewModel(
            survey: survey,
            notificationSentAt: notificationSentAt,
            timeToCompleteMinutes: AppConfiguration.defaultTimeToCompleteMinutes,
            repository: repository,
            locationService: locationService
        )
        self.activeSurveyViewModel = vm
        return vm
    }

    public func openLegalDocument(_ tab: LegalTab) {
        self.activeLegalTab = tab
        self.showingLegalSheet = true
    }

    public func clearActiveSurvey() {
        self.activeSurvey = nil
        self.activeSurveyViewModel = nil
        self.notificationSentAt = nil
        self.isSurveyPresented = false
    }
}
