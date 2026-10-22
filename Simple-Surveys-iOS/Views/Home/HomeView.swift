import SwiftUI

public struct HomeView: View {
    @Bindable public var viewModel: HomeViewModel
    public let repository: SurveyRepositoryProtocol
    public let locationService: LocationServiceProtocol

    @Environment(\.scenePhase) private var scenePhase

    public init(
        viewModel: HomeViewModel,
        repository: SurveyRepositoryProtocol,
        locationService: LocationServiceProtocol
    ) {
        self.viewModel = viewModel
        self.repository = repository
        self.locationService = locationService
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.canvasBackground.ignoresSafeArea()

                if !viewModel.arePermissionsValid {
                    PermissionRevokedView {
                        Task { await viewModel.checkPermissions() }
                    }
                } else {
                    mainContent
                }
            }
            .navigationTitle("Simple Surveys")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.checkPermissions()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.checkPermissions() }
                }
            }
            .fullScreenCover(isPresented: $viewModel.isSurveyPresented) {
                if let surveyVM = viewModel.ensureSurveyViewModel(repository: repository, locationService: locationService) {
                    SurveyContainerView(
                        viewModel: surveyVM,
                        onFinished: {
                            viewModel.clearActiveSurvey()
                        }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showingLegalSheet) {
                LegalSheetView(initialTab: viewModel.activeLegalTab)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    // Header status card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle()
                                .fill(viewModel.activeSurvey != nil ? AppTheme.lightBlue : Color.green)
                                .frame(width: 12, height: 12)
                            Text(viewModel.activeSurvey != nil ? "Active Survey Pending" : "Sampling Schedule Active")
                                .font(.headline)
                                .foregroundColor(AppTheme.navy)
                        }

                        Text("You will receive notifications throughout the day when scheduled survey windows open. Please keep notifications and location enabled.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)

                        #if DEBUG
                        Button(action: {
                            Task {
                                await viewModel.handleIncomingSurveyPrompt(
                                    surveyId: "sample-survey-daily",
                                    sentAt: Date()
                                )
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(AppTheme.gold)
                                Text("Simulate Survey Prompt (Test)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(AppTheme.navy)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(AppTheme.gold.opacity(0.12))
                            .cornerRadius(10)
                        }
                        .padding(.top, 4)
                        #endif
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.pureWhite)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
                    .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)

                    // Active survey prompt banner if available
                    if let survey = viewModel.activeSurvey {
                        // Expiration countdown banner
                        ExpirationBannerView(remainingSeconds: calculateRemainingSeconds())

                        // Scheduled prompt card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(AppTheme.lightBlue)
                                Text("Scheduled Prompt Ready")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.navy)
                            }

                            Text(survey.title)
                                .font(.title3.bold())
                                .foregroundColor(.primary)

                            if let desc = survey.description {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Button(action: {
                                _ = viewModel.ensureSurveyViewModel(repository: repository, locationService: locationService)
                                viewModel.isSurveyPresented = true
                            }) {
                                HStack {
                                    Text("Start Survey")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.pureWhite)
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(AppTheme.lightBlue)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppTheme.navy)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(AppTheme.pureWhite)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.lightBlue, lineWidth: 1.5))
                        .shadow(color: AppTheme.lightBlue.opacity(0.15), radius: 8, x: 0, y: 3)
                    }

                    // Loading prompt spinner
                    if viewModel.isLoading {
                        ProgressView("Loading prompt...")
                            .padding()
                    }

                    // Error banner
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
            }

            Spacer(minLength: 0)

            // Privacy Policy & Terms of Condition button forced to the bottom of the page
            Button(action: {
                viewModel.openLegalDocument(.privacy)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkmark.fill")
                        .font(.caption)
                        .foregroundColor(AppTheme.navy)
                    Text("Privacy Policy & Terms of Condition")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(AppTheme.navy)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(AppTheme.navy.opacity(0.06))
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func calculateRemainingSeconds() -> Int {
        let referenceDate = viewModel.notificationSentAt ?? Date()
        let deadline = referenceDate.addingTimeInterval(Double(AppConfiguration.defaultTimeToCompleteMinutes * 60))
        return max(0, Int(deadline.timeIntervalSince(Date())))
    }
}
