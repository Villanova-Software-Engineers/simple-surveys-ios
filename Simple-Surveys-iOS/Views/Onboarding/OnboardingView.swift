import SwiftUI

public struct OnboardingView: View {
    @Bindable public var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            AppTheme.canvasBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.navy.opacity(0.1))
                            .frame(width: 88, height: 88)
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 42))
                            .foregroundColor(AppTheme.navy)
                    }

                    // Welcome Title
                    VStack(spacing: 6) {
                        Text("Simple Surveys")
                            .font(.largeTitle.bold())
                            .foregroundColor(AppTheme.navy)

                        Text("Experience Sampling Study")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.gold)
                            .textCase(.uppercase)
                    }

                    // Study Participation Requirements Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Study Requirements")
                            .font(.headline)
                            .foregroundColor(AppTheme.navy)

                        Text("Simple Surveys gathers momentary experiences during your everyday routine. To participate, the app requires:")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Divider()

                        permissionRow(
                            icon: "bell.badge.fill",
                            title: "Push Notifications",
                            detail: "Alerts you during active survey sampling windows."
                        )
                        permissionRow(
                            icon: "location.fill",
                            title: "GPS Location",
                            detail: "Attaches approximate coordinates at the moment of submission."
                        )
                        permissionRow(
                            icon: "camera.fill",
                            title: "Camera Access",
                            detail: "Allows you to capture an image of your immediate surroundings."
                        )
                    }
                    .padding(20)
                    .background(AppTheme.pureWhite)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
                    .shadow(color: AppTheme.navy.opacity(0.05), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)

                    // Terms and Conditions Agreement Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "hand.raised.square.fill")
                                .foregroundColor(AppTheme.gold)
                                .font(.title3)
                            Text("Terms & Informed Consent")
                                .font(.headline)
                                .foregroundColor(AppTheme.navy)
                            Spacer()
                            Button("View Details") {
                                viewModel.showingTermsSheet = true
                            }
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.lightBlue)
                        }

                        Text("Your privacy is strictly protected. Submissions are anonymous, with zero personal identifying information collected. An anonymous device token will be registered to deliver scheduled survey prompts.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)

                        Divider()

                        // Interactive Acceptance Checkbox
                        Button(action: { viewModel.toggleTermsAcceptance() }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: viewModel.isTermsAccepted ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundColor(viewModel.isTermsAccepted ? AppTheme.lightBlue : .secondary)

                                Text("I have read, understood, and accept the Terms & Conditions and Informed Consent.")
                                    .font(.footnote.weight(.medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(AppTheme.pureWhite)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(viewModel.isTermsAccepted ? AppTheme.lightBlue : AppTheme.gold.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: AppTheme.navy.opacity(0.05), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)

                    // Status and Error Messages
                    if let status = viewModel.statusMessage {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(status)
                                .font(.footnote)
                                .foregroundColor(AppTheme.navy)
                        }
                        .padding(.horizontal, 24)
                    }

                    if let error = viewModel.errorMessage {
                        VStack(spacing: 8) {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)

                            if viewModel.isTermsAccepted && !viewModel.isRegisteringDevice {
                                Button("Retry Device Registration") {
                                    Task { await viewModel.registerAnonymousDevice() }
                                }
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.lightBlue)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 10)

                    // Accept and Register Button
                    Button(action: {
                        Task { await viewModel.acceptTermsAndRegisterDevice() }
                    }) {
                        HStack {
                            if viewModel.isRequesting || viewModel.isRegisteringDevice {
                                ProgressView().tint(AppTheme.pureWhite)
                                Text("Registering Device...")
                                    .font(.headline.bold())
                                    .foregroundColor(AppTheme.pureWhite)
                            } else {
                                Text("Accept & Enable Device")
                                    .font(.headline.bold())
                                    .foregroundColor(AppTheme.pureWhite)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.lightBlue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(viewModel.isTermsAccepted ? AppTheme.navy : Color.gray.opacity(0.5))
                        .cornerRadius(14)
                    }
                    .disabled(!viewModel.isTermsAccepted || viewModel.isRequesting || viewModel.isRegisteringDevice)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingTermsSheet) {
            TermsAndConditionsView()
        }
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppTheme.lightBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.navy)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
