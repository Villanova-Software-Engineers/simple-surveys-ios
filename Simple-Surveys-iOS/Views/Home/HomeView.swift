import SwiftUI

public struct HomeView: View {
    @Bindable public var viewModel: HomeViewModel
    public let repository: SurveyRepositoryProtocol
    public let locationService: LocationServiceProtocol

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
                await viewModel.syncScheduleAndPrompts()
            }
            .fullScreenCover(isPresented: $viewModel.shouldOpenSurveySheet, onDismiss: {
                viewModel.dismissSurvey()
            }) {
                if let surveyVM = viewModel.currentSurveyViewModel {
                    SurveyContainerView(viewModel: surveyVM)
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
                VStack(spacing: 20) {
                // Warning banner if NOT synced with server
                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.gold)
                        Text(error)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(AppTheme.navy)
                        Spacer()
                        Button(action: {
                            Task { await viewModel.syncScheduleAndPrompts() }
                        }) {
                            Text("Retry")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.lightBlue)
                        }
                        Button(action: { viewModel.errorMessage = nil }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.gold.opacity(0.12))
                    .cornerRadius(10)
                }

                // Status banner if present (e.g. survey completion receipt)
                if let banner = viewModel.statusBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.lightBlue)
                        Text(banner)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(AppTheme.navy)
                        Spacer()
                        Button(action: { viewModel.statusBanner = nil }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.lightBlue.opacity(0.12))
                    .cornerRadius(10)
                }

                // 1. Study Status Header Card
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
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.pureWhite)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
                .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)

                // 2. Active Survey Prompt Banner (with Live Window Countdown)
                if let survey = viewModel.activeSurvey {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Circle()
                                .fill(viewModel.activeSurvey != nil ? AppTheme.lightBlue : Color.green)
                                .frame(width: 12, height: 12)
                            Text(viewModel.activeSurvey != nil ? "Active Survey Pending" : "Sampling Schedule Active")
                                .font(.headline)
                                .foregroundColor(AppTheme.navy)
                            Spacer()

                            // Window status badge
                            if viewModel.activeWindowRemainingSeconds > 0 {
                                TimerBadgeView(remainingSeconds: viewModel.activeWindowRemainingSeconds)
                            } else {
                                Text("Window Expired")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.gold.opacity(0.2))
                                    .foregroundColor(AppTheme.gold)
                                    .clipShape(Capsule())
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(survey.title)
                                .font(.title3.bold())
                                .foregroundColor(.primary)

                            if let desc = survey.description {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                viewModel.startActiveSurvey()
                            }) {
                                HStack {
                                    Text(viewModel.activeWindowRemainingSeconds > 0 ? "Start Survey" : "View Expired Prompt")
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

                            Button(action: {
                                viewModel.clearActiveSurvey()
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.secondary)
                                    .frame(width: 48, height: 48)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.pureWhite)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
                    .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)
                }

                // 3. Developer / Testing Tools Section
                developerTestingToolsSection

                if viewModel.isLoading {
                    ProgressView("Loading prompt...")
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
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
    }

    // MARK: - Developer / Testing Tools Section

    private var developerTestingToolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(AppTheme.navy)
                Text("Developer Testing Tools")
                    .font(.headline)
                    .foregroundColor(AppTheme.navy)
                Spacer()
                Text("[DEV TEST]")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.navy.opacity(0.08))
                    .foregroundColor(AppTheme.navy)
                    .clipShape(Capsule())
            }

            Text("Simulate incoming notifications for testing. Surveys are fetched directly from the backend:")
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineSpacing(2)

            VStack(spacing: 10) {
                Button(action: {
                    Task {
                        await viewModel.simulateSurveyNotification(surveyId: "daily_wellbeing_adaptive")
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.body.weight(.semibold))
                            .foregroundColor(AppTheme.pureWhite)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.lightBlue)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulate Notification: Daily Well-being")
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.navy)
                            Text("ID: daily_wellbeing_adaptive • Fetched from backend")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppTheme.lightBlue)
                    }
                    .padding(12)
                    .background(AppTheme.canvasBackground)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        await viewModel.simulateSurveyNotification(surveyId: "simple_gated_survey")
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.body.weight(.semibold))
                            .foregroundColor(AppTheme.pureWhite)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.gold)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulate Notification: Simple Gated")
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.navy)
                            Text("ID: simple_gated_survey • Fetched from backend")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppTheme.gold)
                    }
                    .padding(12)
                    .background(AppTheme.canvasBackground)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pureWhite)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
        .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
