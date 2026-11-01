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

                // 3. Today's Scheduling & Windows Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(AppTheme.gold)
                            .font(.title3)
                        Text("Today's Schedule & Sampling")
                            .font(.headline)
                            .foregroundColor(AppTheme.navy)
                        Spacer()

                        Button(action: {
                            Task { await viewModel.syncScheduleAndPrompts() }
                        }) {
                            if viewModel.isSyncingSchedule {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Sync")
                                }
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.lightBlue)
                            }
                        }
                        .disabled(viewModel.isSyncingSchedule)
                    }

                    Divider()

                    if let rules = viewModel.samplingRules {
                        scheduleInfoRow(
                            label: "Sampling Mode",
                            value: rules.mode.rawValue.capitalized
                        )
                        scheduleInfoRow(
                            label: "Daily Window",
                            value: "\(rules.dailySchedule.overallWindow.startTime) – \(rules.dailySchedule.overallWindow.endTime)"
                        )
                        scheduleInfoRow(
                            label: "Completion Window",
                            value: "\(rules.timeToCompleteMinutes) minutes from prompt"
                        )
                        scheduleInfoRow(
                            label: "Total Prompts Today",
                            value: "\(viewModel.todayDispatches.count) prompts scheduled"
                        )

                        if let next = viewModel.nextPrompt {
                            scheduleInfoRow(
                                label: "Next Scheduled Prompt",
                                value: formatTime(next.dispatchTime)
                            )
                        } else {
                            scheduleInfoRow(
                                label: "Next Scheduled Prompt",
                                value: "All today's prompts completed"
                            )
                        }
                    } else {
                        Text("Fetching sampling rules from server...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(AppTheme.pureWhite)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
                .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)

                // 4. Notification Verification & Test Controls Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(AppTheme.lightBlue)
                        Text("Notification & Window Verification")
                            .font(.headline)
                            .foregroundColor(AppTheme.navy)
                    }

                    Text("Verify notification delivery and active window countdown on this device:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        Task { await viewModel.triggerTestPrompt(delaySeconds: 5) }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Test Survey Notification (in 5s)")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.navy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.lightBlue.opacity(0.15))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.lightBlue.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding()
                .background(AppTheme.pureWhite)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
                .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)

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

    private func scheduleInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.navy)
        }
    }

    private func timeString(from secs: Int) -> String {
        let mins = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", mins, s)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
