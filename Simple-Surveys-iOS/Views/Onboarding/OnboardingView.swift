import SwiftUI

public struct OnboardingView: View {
    @Bindable public var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            AppTheme.canvasBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Spacer(minLength: 6)

                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.navy.opacity(0.1))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 30))
                            .foregroundColor(AppTheme.navy)
                    }

                    // Welcome Title
                    VStack(spacing: 4) {
                        Text("Simple Surveys")
                            .font(.title2.bold())
                            .foregroundColor(AppTheme.navy)

                        Text("Experience Sampling Study")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.gold)
                            .textCase(.uppercase)
                    }

                    // Study Participation Requirements Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Study Requirements")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.navy)

                        Divider()

                        permissionRow(
                            icon: "bell.badge.fill",
                            title: "Push Notifications",
                            detail: "Alerts for active survey windows."
                        )
                        permissionRow(
                            icon: "location.fill",
                            title: "GPS Location",
                            detail: "Captured only upon survey submission."
                        )
                        permissionRow(
                            icon: "camera.fill",
                            title: "Camera Access",
                            detail: "Optional photos of your surroundings."
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.pureWhite)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))
                    .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    // Terms and Conditions Agreement Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "hand.raised.square.fill")
                                .foregroundColor(AppTheme.gold)
                                .font(.subheadline)
                            Text("Terms & Informed Consent")
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.navy)
                            Spacer()
                            Button("View Details") {
                                viewModel.showingTermsSheet = true
                            }
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.lightBlue)
                        }

                        Text("Submissions are anonymous. No personal identifying information is collected.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        // Interactive Acceptance Checkbox
                        Button(action: { viewModel.toggleTermsAcceptance() }) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.isTermsAccepted ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundColor(viewModel.isTermsAccepted ? AppTheme.lightBlue : .secondary)

                                Text("I accept the Terms & Conditions and Informed Consent.")
                                    .font(.footnote.weight(.medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.pureWhite)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(viewModel.isTermsAccepted ? AppTheme.lightBlue : AppTheme.gold.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)
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
                        VStack(spacing: 6) {
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
                        .frame(height: 50)
                        .background(viewModel.isTermsAccepted ? AppTheme.navy : Color.gray.opacity(0.5))
                        .cornerRadius(14)
                    }
                    .disabled(!viewModel.isTermsAccepted || viewModel.isRequesting || viewModel.isRegisteringDevice)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingTermsSheet) {
            TermsAndConditionsView()
        }
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppTheme.lightBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
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
