import SwiftUI

public struct NumericQuestionView: View {
    public let question: Question
    @Binding public var answer: AnyCodableValue?

    @State private var textValue: String = ""
    @State private var validationError: String? = nil

    public init(question: Question, answer: Binding<AnyCodableValue?>) {
        self.question = question
        self._answer = answer
        _textValue = State(initialValue: Self.formatInitial(answer.wrappedValue))
    }

    private var minValue: Double? { question.validationRules?.minValue }
    private var maxValue: Double? { question.validationRules?.maxValue }
    private var allowDecimals: Bool { question.validationRules?.allowDecimals == true }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.prompt)
                .font(.headline)
                .foregroundColor(AppTheme.navy)

            HStack {
                TextField(placeholderText, text: $textValue)
                    .keyboardType(allowDecimals ? .decimalPad : .numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: textValue) { oldValue, newValue in
                        handleTextChange(oldValue: oldValue, newValue: newValue)
                    }

                if let max = maxValue {
                    Text("/ \(formatNumber(max))")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.navy.opacity(0.6))
                        .padding(.trailing, 4)
                }
            }

            if let err = validationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text(err)
                        .font(.caption)
                }
                .foregroundColor(.red)
            } else if let min = minValue, let max = maxValue {
                Text("Enter a value between \(formatNumber(min)) and \(formatNumber(max))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let max = maxValue {
                Text("Maximum allowed: \(formatNumber(max))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(AppTheme.pureWhite)
        .cornerRadius(12)
        .shadow(color: AppTheme.navy.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private var placeholderText: String {
        question.validationRules?.placeholder ?? "0"
    }

    private func handleTextChange(oldValue: String, newValue: String) {
        if newValue.isEmpty {
            answer = nil
            validationError = nil
            return
        }

        // Prevent decimal points if decimals are not allowed
        if !allowDecimals && (newValue.contains(".") || newValue.contains(",")) {
            textValue = oldValue
            return
        }

        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(normalized) else {
            // Disallow non-numeric characters
            textValue = oldValue
            return
        }

        // Enforce maximum constraint in real-time
        if let max = maxValue, d > max {
            textValue = oldValue
            validationError = "Cannot exceed \(formatNumber(max))"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        // Validate minimum constraint
        if let min = minValue, d < min {
            answer = nil
            validationError = "Minimum value is \(formatNumber(min))"
            return
        }

        validationError = nil
        answer = allowDecimals ? .double(d) : .int(Int(d))
    }

    private func formatNumber(_ num: Double) -> String {
        if num.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(num))
        }
        return String(num)
    }

    private static func formatInitial(_ val: AnyCodableValue?) -> String {
        guard let val = val else { return "" }
        if case .int(let i) = val { return String(i) }
        if case .double(let d) = val {
            if d.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(d))
            }
            return String(d)
        }
        return ""
    }
}
