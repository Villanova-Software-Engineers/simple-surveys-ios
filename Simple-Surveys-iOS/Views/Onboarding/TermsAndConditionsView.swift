import SwiftUI

public struct TermsAndConditionsView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Terms of Participation")
                            .font(.title2.bold())
                            .foregroundColor(AppTheme.navy)

                        Text("Simple Surveys Experience Sampling Study")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.gold)
                    }
                    .padding(.bottom, 4)

                    Divider()

                    // Section 1: Study Purpose
                    sectionCard(
                        icon: "doc.text.magnifyingglass",
                        title: "1. Purpose of the Study",
                        text: "This research study uses Experience Sampling Methods (ESM) to measure real-time experiences, environmental contexts, and momentary states throughout daily life. You will receive brief survey prompts during predefined daily sampling windows."
                    )

                    // Section 2: Strict Participant Anonymity
                    sectionCard(
                        icon: "lock.shield.fill",
                        title: "2. Zero Tracking & Strict Anonymity",
                        text: "Your participation is completely anonymous. The application does not collect, record, or store your name, email address, phone number, advertising identifiers (IDFA), or personal account credentials. All responses are stored under an anonymous session key."
                    )

                    // Section 3: Anonymous Device Registration
                    sectionCard(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "3. Anonymous Device Token",
                        text: "Upon accepting these terms, an anonymous device push notification token is generated and registered with the study server (POST /api/notifications/devices). This token is used exclusively to dispatch scheduled survey prompts during your active windows and cannot be linked to your personal identity."
                    )

                    // Section 4: Data Collection & Permissions
                    sectionCard(
                        icon: "hand.raised.fill",
                        title: "4. Survey Data & Sensor Use",
                        text: "• Push Notifications: Alerts you when a scheduled survey window opens.\n• GPS Coordinates: Recorded strictly at the moment you submit a survey response to contextualize environmental data.\n• Camera Capture: Allows you to optionally capture a photograph of your immediate surroundings."
                    )

                    // Section 5: Expiration Window
                    sectionCard(
                        icon: "timer",
                        title: "5. Time-to-Complete Window",
                        text: "Surveys must be initiated and completed within the study's designated window (typically 5 minutes from prompt dispatch). If a survey expires before completion, an anonymous audit marker is recorded."
                    )

                    // Section 6: Voluntary Participation
                    sectionCard(
                        icon: "person.badge.shield.checkmark.fill",
                        title: "6. Voluntary Participation & Withdrawal",
                        text: "Participation is voluntary. You may stop participating at any time by removing the application or disabling notifications in your device settings."
                    )
                }
                .padding()
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.navy)
                    .bold()
                }
            }
        }
    }

    private func sectionCard(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.lightBlue)
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.navy)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pureWhite)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.navy.opacity(0.08), lineWidth: 1))
    }
}
