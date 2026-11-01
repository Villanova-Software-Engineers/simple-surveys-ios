import SwiftUI

@main
struct SimpleSurveysApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var onboardingViewModel: OnboardingViewModel
    @State private var homeViewModel: HomeViewModel

    private let apiClient: APIClientProtocol
    private let repository: SurveyRepositoryProtocol
    private let locationService: LocationServiceProtocol
    private let cameraService: CameraServiceProtocol
    private let permissionManager: PermissionManagerProtocol
    private let scheduler: NotificationSchedulerProtocol

    init() {
        let client = APIClient(baseURL: AppConfiguration.apiBaseURL)
        let repo = SurveyRepository(apiClient: client)
        let loc = LocationService()
        let cam = CameraService()
        let perms = PermissionManager(locationService: loc, cameraService: cam)
        let sched = NotificationScheduler(repository: repo)

        self.apiClient = client
        self.repository = repo
        self.locationService = loc
        self.cameraService = cam
        self.permissionManager = perms
        self.scheduler = sched

        _onboardingViewModel = State(
            initialValue: OnboardingViewModel(
                permissionManager: perms,
                repository: repo,
                scheduler: sched
            )
        )
        _homeViewModel = State(
            initialValue: HomeViewModel(
                repository: repo,
                permissionManager: perms,
                scheduler: sched,
                locationService: loc
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingViewModel.hasCompletedOnboarding {
                    OnboardingView(viewModel: onboardingViewModel)
                } else {
                    HomeView(
                        viewModel: homeViewModel,
                        repository: repository,
                        locationService: locationService
                    )
                }
            }
            .preferredColorScheme(.light)
            .onReceive(NotificationCenter.default.publisher(for: .openSurveyFromNotification)) { notification in
                if let userInfo = notification.userInfo,
                   let surveyId = userInfo["survey_id"] as? String {
                    let sentAt = userInfo["notification_sent_at"] as? Date
                    let timeToComplete = userInfo["time_to_complete_minutes"] as? Int
                    Task {
                        await homeViewModel.handleIncomingSurveyPrompt(
                            surveyId: surveyId,
                            sentAt: sentAt,
                            timeToComplete: timeToComplete,
                            autoOpen: true
                        )
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .surveyPromptReceived)) { notification in
                if let userInfo = notification.userInfo,
                   let surveyId = userInfo["survey_id"] as? String {
                    let sentAt = userInfo["notification_sent_at"] as? Date
                    let timeToComplete = userInfo["time_to_complete_minutes"] as? Int
                    Task {
                        await homeViewModel.handleIncomingSurveyPrompt(
                            surveyId: surveyId,
                            sentAt: sentAt,
                            timeToComplete: timeToComplete,
                            autoOpen: false
                        )
                    }
                }
            }
        }
    }
}
