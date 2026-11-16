import SwiftUI

public struct RatingScaleQuestionView: View {
    public let question: Question
    @Binding public var answer: AnyCodableValue?

    public init(question: Question, answer: Binding<AnyCodableValue?>) {
        self.question = question
        self._answer = answer
    }

    private var minValue: Int { Int(question.validationRules?.minValue ?? 1) }
    private var maxValue: Int { Int(question.validationRules?.maxValue ?? 10) }
    private var step: Int { Int(question.validationRules?.step ?? 1) }

    private var values: [Int] {
        Array(stride(from: minValue, through: maxValue, by: step))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(question.prompt)
                    .font(.headline)
                    .foregroundColor(AppTheme.navy)

                Spacer(minLength: 8)

                if let selected = selectedInt {
                    HStack(spacing: 4) {
                        Text("Rating:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(selected)")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.navy)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.lightBlue.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // Single line bar fitting all numbers without scrolling
            HStack(spacing: 4) {
                ForEach(values, id: \.self) { value in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        answer = .int(value)
                    }) {
                        Text("\(value)")
                            .font(.system(size: values.count > 7 ? 13 : 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(selectedInt == value ? AppTheme.navy : Color(.secondarySystemBackground))
                            .foregroundColor(selectedInt == value ? AppTheme.pureWhite : AppTheme.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedInt == value ? AppTheme.lightBlue : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let minLabel = question.validationRules?.minLabel,
               let maxLabel = question.validationRules?.maxLabel {
                HStack {
                    Text("\(minValue) = \(minLabel)").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("\(maxValue) = \(maxLabel)").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(AppTheme.pureWhite)
        .cornerRadius(12)
        .shadow(color: AppTheme.navy.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var selectedInt: Int? {
        if case .int(let v) = answer { return v }
        return nil
    }
}
