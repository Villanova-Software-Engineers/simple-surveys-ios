import SwiftUI

public struct SurveyCompletedView: View {
    public let onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.lightBlue)

            Text("Check-In Submitted")
                .font(.title2.bold())
                .foregroundColor(AppTheme.navy)

            Text("Thank you! Your survey response has been saved anonymously.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }) {
                Text("Return to Dashboard")
                    .font(.headline)
                    .foregroundColor(AppTheme.pureWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.navy)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .padding()
    }
}
