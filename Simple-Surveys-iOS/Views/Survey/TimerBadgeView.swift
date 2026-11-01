import SwiftUI

public struct TimerBadgeView: View {
    public let remainingSeconds: Int

    public init(remainingSeconds: Int) {
        self.remainingSeconds = remainingSeconds
    }

    public var body: some View {
        Text(timeString(from: remainingSeconds))
            .font(.caption.bold())
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(remainingSeconds < 60 ? Color.red.opacity(0.18) : AppTheme.lightBlue.opacity(0.2))
            .foregroundColor(remainingSeconds < 60 ? .red : AppTheme.navy)
            .clipShape(Capsule())
            .fixedSize()
    }

    private func timeString(from secs: Int) -> String {
        let mins = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", mins, s)
    }
}
