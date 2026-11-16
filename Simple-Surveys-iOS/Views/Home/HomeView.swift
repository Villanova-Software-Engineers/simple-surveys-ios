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
        ScrollView {
            VStack(spacing: 20) {
                // Status banner if present
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

                if viewModel.isLoading {
                    ProgressView("Loading prompt...")
                        .padding()
                }

                Spacer(minLength: 20)
            }
            .padding()

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
}
