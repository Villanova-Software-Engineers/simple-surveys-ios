import SwiftUI

public enum LegalTab: String, CaseIterable, Identifiable {
    case privacy = "Privacy Policy"
    case terms = "Terms & Conditions"

    public var id: String { rawValue }
}

private struct BottomMarkerPreference: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

public struct LegalSheetView: View {
    @State public var selectedTab: LegalTab
    public var onAccept: (() -> Void)? = nil

    @State private var hasScrolledToBottom: Bool = false
    @Environment(\.dismiss) private var dismiss

    public init(initialTab: LegalTab = .privacy, onAccept: (() -> Void)? = nil) {
        _selectedTab = State(initialValue: initialTab)
        self.onAccept = onAccept
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // If in consent pop-up mode (onAccept != nil), show combined scrollable agreement with scroll requirement
                if onAccept != nil {
                    consentPopUpContent
                } else {
                    tabbedViewerContent
                }

                // If in consent pop-up mode, show sticky bottom action bar gated by scrolling
                if let onAccept = onAccept {
                    bottomActionBar(onAccept: onAccept)
                }
            }
            .navigationTitle(onAccept != nil ? "Consent & Privacy Policy" : "Privacy Policy & Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onAccept != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.navy)
                    }
                } else {
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
    }

    // MARK: - Tabbed Viewer for Read-Only Mode (e.g. from HomeView)
    private var tabbedViewerContent: some View {
        VStack(spacing: 0) {
            Picker("Policy Document", selection: $selectedTab) {
                ForEach(LegalTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(AppTheme.pureWhite)

            Divider()

            Group {
                if selectedTab == .privacy {
                    PrivacyPolicyContentView()
                } else {
                    TermsAndConditionsContentView()
                }
            }
        }
    }

    // MARK: - Combined Scrollable Document for Consent Pop-Up Mode
    private var consentPopUpContent: some View {
        GeometryReader { scrollContainerGeo in
            ScrollViewReader { proxy in
                ZStack {
                    AppTheme.canvasBackground.ignoresSafeArea()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            // Top Notice & Jump Bar
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: hasScrolledToBottom ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(hasScrolledToBottom ? .green : AppTheme.gold)

                                    Text(hasScrolledToBottom ? "Entire Agreement Reviewed" : "Scroll to Bottom to Accept")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.navy)
                                }

                                Text("Please scroll through both the Privacy Policy and Terms of Participation below to unlock the acceptance button.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)

                                // Quick section jump links
                                HStack(spacing: 10) {
                                    Button(action: {
                                        withAnimation { proxy.scrollTo("privacy_section", anchor: .top) }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "shield.fill")
                                            Text("1. Privacy Policy")
                                        }
                                        .font(.caption2.bold())
                                        .foregroundColor(AppTheme.navy)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppTheme.navy.opacity(0.08))
                                        .cornerRadius(8)
                                    }

                                    Button(action: {
                                        withAnimation { proxy.scrollTo("terms_section", anchor: .top) }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.plaintext.fill")
                                            Text("2. Terms & Conditions")
                                        }
                                        .font(.caption2.bold())
                                        .foregroundColor(AppTheme.navy)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppTheme.navy.opacity(0.08))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.pureWhite)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(hasScrolledToBottom ? Color.green.opacity(0.3) : AppTheme.gold.opacity(0.4), lineWidth: 1.5))
                            .shadow(color: AppTheme.navy.opacity(0.04), radius: 6, x: 0, y: 2)

                            // PART 1: Privacy Policy
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .font(.title3)
                                        .foregroundColor(AppTheme.navy)
                                    Text("Part 1: Privacy Policy")
                                        .font(.title3.bold())
                                        .foregroundColor(AppTheme.navy)
                                }
                                .id("privacy_section")

                                Text("Strict Anonymity & Participant Data Protection")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppTheme.gold)
                                    .textCase(.uppercase)
                            }
                            .padding(.top, 6)

                            PrivacyPolicySectionsView()

                            Divider()
                                .padding(.vertical, 8)

                            // PART 2: Terms & Conditions
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: "doc.plaintext.fill")
                                        .font(.title3)
                                        .foregroundColor(AppTheme.navy)
                                    Text("Part 2: Terms & Conditions")
                                        .font(.title3.bold())
                                        .foregroundColor(AppTheme.navy)
                                }
                                .id("terms_section")

                                Text("Study Participation Requirements & Protocol")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppTheme.gold)
                                    .textCase(.uppercase)
                            }
                            .padding(.top, 6)

                            TermsAndConditionsSectionsView()

                            // End of Agreement Card (Trigger for Scroll-to-Bottom)
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.lightBlue)

                                Text("You Have Reached the End")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.navy)

                                Text("Thank you for reviewing the full Study Agreement and Privacy Policy. You can now tap the button below to enable permissions and begin.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.pureWhite)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.lightBlue.opacity(0.5), lineWidth: 1.5))
                            .shadow(color: AppTheme.navy.opacity(0.05), radius: 6, x: 0, y: 2)
                            .padding(.top, 10)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    hasScrolledToBottom = true
                                }
                            }

                            // Coordinate space marker for preference key detection
                            GeometryReader { markerGeo in
                                Color.clear.preference(
                                    key: BottomMarkerPreference.self,
                                    value: markerGeo.frame(in: .named("consentScrollSpace")).maxY
                                )
                            }
                            .frame(height: 20)
                        }
                        .padding()
                    }
                    .coordinateSpace(name: "consentScrollSpace")
                    .onPreferenceChange(BottomMarkerPreference.self) { bottomY in
                        if bottomY <= scrollContainerGeo.size.height + 60 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                hasScrolledToBottom = true
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sticky Bottom Action Bar
    private func bottomActionBar(onAccept: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Divider()

            Button(action: {
                if hasScrolledToBottom {
                    dismiss()
                    onAccept()
                }
            }) {
                HStack(spacing: 8) {
                    if hasScrolledToBottom {
                        Text("Agree & Enable Permissions")
                            .font(.headline.bold())
                            .foregroundColor(AppTheme.pureWhite)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(AppTheme.lightBlue)
                    } else {
                        Text("Scroll to Bottom to Accept")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.pureWhite.opacity(0.85))
                        Image(systemName: "arrow.down.circle")
                            .font(.headline)
                            .foregroundColor(AppTheme.pureWhite.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(hasScrolledToBottom ? AppTheme.navy : AppTheme.navy.opacity(0.4))
                .cornerRadius(14)
            }
            .disabled(!hasScrolledToBottom)
            .padding(.horizontal, 20)
            .padding(.top, 4)

            Text(hasScrolledToBottom ? "By tapping agree, you accept the Privacy Policy & Terms of Participation." : "Please scroll through the whole agreement above to unlock this button.")
                .font(.caption2)
                .foregroundColor(hasScrolledToBottom ? .secondary : AppTheme.gold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
        }
        .background(AppTheme.pureWhite)
    }
}

// MARK: - Reusable Embeddable Privacy Policy Sections
public struct PrivacyPolicySectionsView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            privacyCard(
                icon: "person.crop.circle.badge.xmark",
                title: "1. Zero Participant Tracking Commitment",
                content: "Simple Surveys is engineered from the ground up to protect participant anonymity. The app contains NO user registration, NO login credentials, and collects NO personal identifiers such as your name, email address, phone number, contacts, or Advertising Identifier (IDFA). Each submitted survey is treated as an isolated research event."
            )

            privacyCard(
                icon: "bell.fill",
                title: "2. Push Notification Token (APNs)",
                content: "To notify you when a survey prompt is active, the app registers an anonymous hexadecimal device token with the Apple Push Notification service (APNs) and transmits it to our secure backend (POST /api/notifications/devices). This token is never linked to your personal identity and is used solely to deliver scheduled survey alerts."
            )

            privacyCard(
                icon: "location.fill",
                title: "3. Geolocation Coordinates (CoreLocation)",
                content: "When you submit a survey response (or when a survey window expires), the app acquires your approximate location (latitude, longitude, altitude, horizontal accuracy). Location data is collected ONLY at the single instant of survey submission. Simple Surveys does NOT track your location in the background or monitor your movements."
            )

            privacyCard(
                icon: "camera.fill",
                title: "4. Surroundings Photos (AVFoundation)",
                content: "If a survey requests an optional surroundings photograph, camera access is requested. Captured images are compressed locally on your device to standard research dimensions (max 1080p, 0.8 JPEG quality) before uploading. The app performs no facial recognition, biometric analysis, or indexing of image metadata."
            )

            privacyCard(
                icon: "timer",
                title: "5. Survey Timestamps & Expiration Audits",
                content: "To evaluate response timeliness, the app records timestamps for when the notification was dispatched, when the survey was opened, and when answers were submitted. If the countdown reaches zero, an empty audit record (status: 'EXPIRED', answers: []) is logged without capturing unsubmitted answers."
            )

            privacyCard(
                icon: "lock.shield.fill",
                title: "6. Data Transmission & Storage Security",
                content: "All communication between the iOS application and the backend server is encrypted using Transport Layer Security (TLS/HTTPS). Survey responses and optional photos are stored in secure research databases with access restricted to authorized university research personnel."
            )

            privacyCard(
                icon: "hand.raised.fill",
                title: "7. Zero Third-Party Tracking & Commercial Sale",
                content: "The application contains zero commercial advertising networks, zero third-party tracking SDKs, and zero social media plugins. Your data is never sold, leased, or monetized."
            )

            privacyCard(
                icon: "slider.horizontal.3",
                title: "8. Participant Control & Revocation",
                content: "You can revoke camera, notification, or location permissions at any time in iOS Settings. Revoking a required permission pauses survey prompts and displays a lockout screen until permissions are restored."
            )

            privacyCard(
                icon: "envelope.fill",
                title: "9. Research Inquiries & Contact",
                content: "For questions regarding this privacy policy or how study data is handled, please contact the Simple Surveys Research Team at Villanova Software Engineers."
            )
        }
    }

    private func privacyCard(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppTheme.lightBlue)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.navy.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.navy)
            }

            Text(content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(2.5)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pureWhite)
        .cornerRadius(12)
        .shadow(color: AppTheme.navy.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Reusable Embeddable Terms & Conditions Sections
public struct TermsAndConditionsSectionsView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalSection(
                number: "1",
                title: "Study Purpose & Scope",
                content: "Simple Surveys is an academic Experience Sampling Method (ESM) mobile research application designed to gather real-time behavioral and environmental context from participants. By downloading, accessing, or using this application, you agree to be bound by these Terms and Conditions."
            )

            legalSection(
                number: "2",
                title: "Eligibility & Voluntary Participation",
                content: "Participation in this research study is entirely voluntary. You must be at least 18 years of age to participate. You have the right to withdraw from the study at any time without penalty or loss of benefit. You may discontinue your participation by revoking app permissions in iOS Settings or deleting the application from your device."
            )

            legalSection(
                number: "3",
                title: "Scheduled Surveys & Expiration Windows",
                content: "Surveys are scheduled and delivered via push notifications throughout the day. To ensure scientific validity, each survey is active only for a strict time window (default 5 minutes from receipt). If you do not submit your survey within this window, the survey will expire. When a survey expires, an anonymous audit record is transmitted to document the missed window with zero answers recorded."
            )

            legalSection(
                number: "4",
                title: "Surroundings Photo Guidelines",
                content: "Surveys may include an optional request to capture an image of your immediate physical surroundings. If you choose to submit a photograph, you agree to:\n• Photograph only the environment and physical surroundings.\n• Avoid capturing identifiable faces of third parties without their explicit consent.\n• Refrain from capturing confidential documents, private residences of others, or sensitive personal data.\n• Not transmit inappropriate, illicit, or defamatory imagery."
            )

            legalSection(
                number: "5",
                title: "Geolocation Coordinates (GPS)",
                content: "Upon submitting a completed or expired survey, the app acquires approximate GPS coordinates (latitude, longitude, altitude, horizontal accuracy). Geolocation is recorded solely at the moment of submission to correlate responses with environmental factors. Continuous background location tracking is never performed."
            )

            legalSection(
                number: "6",
                title: "Strict Anonymity & Zero Account Architecture",
                content: "The application operates on a strict zero-tracking architecture. No personal accounts, passwords, email addresses, phone numbers, or Advertising Identifiers (IDFA) are collected or associated with your survey responses. Your push notification token is an anonymous identifier used solely for dispatching survey alerts."
            )

            legalSection(
                number: "7",
                title: "Academic Research & Data Ownership",
                content: "Anonymous survey responses and environmental observations collected through the application are used exclusively for academic research, statistical analysis, and scholarly publications. Published research will present aggregated findings and will never reveal individual participant identities."
            )

            legalSection(
                number: "8",
                title: "Researcher Contact & Inquiries",
                content: "If you have questions regarding these Terms and Conditions or the study protocol, please contact the Simple Surveys Research Team / Villanova Software Engineers through the study administration channels."
            )
        }
    }

    private func legalSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(number)
                    .font(.caption.bold())
                    .frame(width: 22, height: 22)
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
                .lineSpacing(2.5)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pureWhite)
        .cornerRadius(12)
        .shadow(color: AppTheme.navy.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Reusable Standalone Content Views for Tabbed Viewer
public struct TermsAndConditionsContentView: View {
    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.canvasBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "doc.plaintext.fill")
                                .font(.title3)
                                .foregroundColor(AppTheme.navy)
                            Text("Terms & Conditions")
                                .font(.title3.bold())
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
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))

                    TermsAndConditionsSectionsView()

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
    }
}

public struct PrivacyPolicyContentView: View {
    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.canvasBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.title3)
                                .foregroundColor(AppTheme.navy)
                            Text("Privacy Policy")
                                .font(.title3.bold())
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
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.navy.opacity(0.1), lineWidth: 1))

                    PrivacyPolicySectionsView()

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
    }
}
