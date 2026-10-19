import SwiftUI

public struct PrivacyPolicyView: View {
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
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.title2)
                                    .foregroundColor(AppTheme.navy)
                                Text("Privacy Policy")
                                    .font(.title2.bold())
                                    .foregroundColor(AppTheme.navy)
                            }

                            Text("Strict Anonymity & Participant Data Protection")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppTheme.gold)
                                .textCase(.uppercase)

                            Text("Last Updated: October 2026 • Compliant with Apple App Store Guidelines")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.pureWhite)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))

                        // Section 1
                        privacyCard(
                            icon: "person.crop.circle.badge.xmark",
                            title: "1. Zero Participant Tracking Commitment",
                            content: "Simple Surveys is engineered from the ground up to protect participant anonymity. The app contains NO user registration, NO login credentials, and collects NO personal identifiers such as your name, email address, phone number, contacts, or Advertising Identifier (IDFA). Each submitted survey is treated as an isolated research event."
                        )

                        // Section 2
                        privacyCard(
                            icon: "bell.fill",
                            title: "2. Push Notification Token (APNs)",
                            content: "To notify you when a survey prompt is active, the app registers an anonymous hexadecimal device token with the Apple Push Notification service (APNs) and transmits it to our secure backend (POST /api/notifications/devices). This token is never linked to your personal identity and is used solely to deliver scheduled survey alerts."
                        )

                        // Section 3
                        privacyCard(
                            icon: "location.fill",
                            title: "3. Geolocation Coordinates (CoreLocation)",
                            content: "When you submit a survey response (or when a survey window expires), the app acquires your approximate location (latitude, longitude, altitude, horizontal accuracy). Location data is collected ONLY at the single instant of survey submission. Simple Surveys does NOT track your location in the background or monitor your movements."
                        )

                        // Section 4
                        privacyCard(
                            icon: "camera.fill",
                            title: "4. Surroundings Photos (AVFoundation)",
                            content: "If a survey requests an optional surroundings photograph, camera access is requested. Captured images are compressed locally on your device to standard research dimensions (max 1080p, 0.8 JPEG quality) before uploading. The app performs no facial recognition, biometric analysis, or indexing of image metadata."
                        )

                        // Section 5
                        privacyCard(
                            icon: "timer",
                            title: "5. Survey Timestamps & Expiration Audits",
                            content: "To evaluate response timeliness, the app records timestamps for when the notification was dispatched, when the survey was opened, and when answers were submitted. If the countdown reaches zero, an empty audit record (status: 'EXPIRED', answers: []) is logged without capturing unsubmitted answers."
                        )

                        // Section 6
                        privacyCard(
                            icon: "lock.shield.fill",
                            title: "6. Data Transmission & Storage Security",
                            content: "All communication between the iOS application and the backend server is encrypted using Transport Layer Security (TLS/HTTPS). Survey responses and optional photos are stored in secure research databases with access restricted to authorized university research personnel."
                        )

                        // Section 7
                        privacyCard(
                            icon: "hand.raised.fill",
                            title: "7. Zero Third-Party Tracking & Commercial Sale",
                            content: "The application contains zero commercial advertising networks, zero third-party tracking SDKs, and zero social media plugins. Your data is never sold, leased, or monetized."
                        )

                        // Section 8
                        privacyCard(
                            icon: "slider.horizontal.3",
                            title: "8. Participant Control & Revocation",
                            content: "You can revoke camera, notification, or location permissions at any time in iOS Settings. Revoking a required permission pauses survey prompts and displays a lockout screen until permissions are restored."
                        )

                        // Section 9
                        privacyCard(
                            icon: "envelope.fill",
                            title: "9. Research Inquiries & Contact",
                            content: "For questions regarding this privacy policy or how study data is handled, please contact the Simple Surveys Research Team at Villanova Software Engineers."
                        )

                        // Dismiss button
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
            .navigationTitle("Privacy Policy")
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

    private func privacyCard(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.lightBlue)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.navy.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

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
