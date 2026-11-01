import SwiftUI

public struct SurveyCompletedView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 68))
                .foregroundColor(AppTheme.lightBlue)

            VStack(spacing: 8) {
                Text("Check-In Submitted")
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.navy)

                Text("Thank you! Your survey response was completed within the window and saved anonymously to the study database.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("Return to Dashboard")
                    .font(.headline.bold())
                    .foregroundColor(AppTheme.pureWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.navy)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding()
    }
}
