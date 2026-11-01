import SwiftUI

public struct ExpiredSurveyView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.badge.xmark.fill")
                .font(.system(size: 68))
                .foregroundColor(AppTheme.gold)

            VStack(spacing: 8) {
                Text("Survey Window Expired")
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.navy)

                Text("This experience sampling prompt was not completed within the allotted time window. An anonymous audit record has been sent to the research server.")
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
