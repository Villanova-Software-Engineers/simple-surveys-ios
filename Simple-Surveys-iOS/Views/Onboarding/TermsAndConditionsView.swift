import SwiftUI

public struct TermsAndConditionsView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.canvasBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Banner
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.plaintext.fill")
                                    .font(.title2)
                                    .foregroundColor(AppTheme.navy)
                                Text("Terms & Conditions")
                                    .font(.title2.bold())
                                    .foregroundColor(AppTheme.navy)
                            }

                            Text("Simple Surveys Experience Sampling Study")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.gold)
                                .textCase(.uppercase)

                            Text("Effective: October 2026 • Version 1.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.pureWhite)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))

                        // Section 1
                        legalSection(
                            number: "1",
                            title: "Study Purpose & Scope",
                            content: "Simple Surveys is an academic Experience Sampling Method (ESM) mobile research application designed to gather real-time behavioral and environmental context from participants. By downloading, accessing, or using this application, you agree to be bound by these Terms and Conditions."
                        )

                        // Section 2
                        legalSection(
                            number: "2",
                            title: "Eligibility & Voluntary Participation",
                            content: "Participation in this research study is entirely voluntary. You must be at least 18 years of age to participate. You have the right to withdraw from the study at any time without penalty or loss of benefit. You may discontinue your participation by revoking app permissions in iOS Settings or deleting the application from your device."
                        )

                        // Section 3
                        legalSection(
                            number: "3",
                            title: "Scheduled Surveys & Expiration Windows",
                            content: "Surveys are scheduled and delivered via push notifications throughout the day. To ensure scientific validity, each survey is active only for a strict time window (default 5 minutes from receipt). If you do not submit your survey within this window, the survey will expire. When a survey expires, an anonymous audit record is transmitted to document the missed window with zero answers recorded."
                        )

                        // Section 4
                        legalSection(
                            number: "4",
                            title: "Surroundings Photo Guidelines",
                            content: "Surveys may include an optional request to capture an image of your immediate physical surroundings. If you choose to submit a photograph, you agree to:\n• Photograph only the environment and physical surroundings.\n• Avoid capturing identifiable faces of third parties without their explicit consent.\n• Refrain from capturing confidential documents, private residences of others, or sensitive personal data.\n• Not transmit inappropriate, illicit, or defamatory imagery."
                        )

                        // Section 5
                        legalSection(
                            number: "5",
                            title: "Geolocation Coordinates (GPS)",
                            content: "Upon submitting a completed or expired survey, the app acquires approximate GPS coordinates (latitude, longitude, altitude, horizontal accuracy). Geolocation is recorded solely at the moment of submission to correlate responses with environmental factors. Continuous background location tracking is never performed."
                        )

                        // Section 6
                        legalSection(
                            number: "6",
                            title: "Strict Anonymity & Zero Account Architecture",
                            content: "The application operates on a strict zero-tracking architecture. No personal accounts, passwords, email addresses, phone numbers, or Advertising Identifiers (IDFA) are collected or associated with your survey responses. Your push notification token is an anonymous identifier used solely for dispatching survey alerts."
                        )

                        // Section 7
                        legalSection(
                            number: "7",
                            title: "Academic Research & Data Ownership",
                            content: "Anonymous survey responses and environmental observations collected through the application are used exclusively for academic research, statistical analysis, and scholarly publications. Published research will present aggregated findings and will never reveal individual participant identities."
                        )

                        // Section 8
                        legalSection(
                            number: "8",
                            title: "Researcher Contact & Inquiries",
                            content: "If you have questions regarding these Terms and Conditions or the study protocol, please contact the Simple Surveys Research Team / Villanova Software Engineers through the study administration channels."
                        )

                        // Dismiss button at bottom
                        Button(action: { dismiss() }) {
                            Text("I Understand & Close")
                                .font(.headline)
                                .foregroundColor(AppTheme.pureWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AppTheme.navy)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(AppTheme.navy)
                }
            }
        }
    }

    private func legalSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(number)
                    .font(.caption.bold())
                    .frame(width: 24, height: 24)
                    .background(AppTheme.lightBlue.opacity(0.15))
                    .foregroundColor(AppTheme.navy)
                    .clipShape(Circle())

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.navy)
            }

            Text(content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pureWhite)
        .cornerRadius(14)
        .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
