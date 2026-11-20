import SwiftUI

/// Free-text response input view supporting OpenJev semantic gating evaluations.
public struct TextQuestionView: View {
    public let question: Question
    @Binding public var answer: AnyCodableValue?
    public var onTextChanged: ((String) -> Void)?
    public var onBlur: ((String) -> Void)?
    public var gatingScoreInfo: GatingEvaluationScore?

    @FocusState private var isFocused: Bool

    public init(
        question: Question,
        answer: Binding<AnyCodableValue?>,
        onTextChanged: ((String) -> Void)? = nil,
        onBlur: ((String) -> Void)? = nil,
        gatingScoreInfo: GatingEvaluationScore? = nil
    ) {
        self.question = question
        self._answer = answer
        self.onTextChanged = onTextChanged
        self.onBlur = onBlur
        self.gatingScoreInfo = gatingScoreInfo
    }

    private var placeholder: String {
        question.validationRules?.placeholder ?? "Enter your response here..."
    }

    private var maxLength: Int {
        question.validationRules?.maxLength ?? 500
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.prompt)
                .font(.headline)
                .foregroundColor(AppTheme.navy)

            ZStack(alignment: .topLeading) {
                if currentText.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color(UIColor.placeholderText))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: textBinding)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 120)
                    .padding(4)
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        gatingScoreInfo?.matched == true ? Color.green.opacity(0.6) : Color(.systemGray4),
                        lineWidth: 1
                    )
            )

            HStack {
                if let scoreInfo = gatingScoreInfo {
                    HStack(spacing: 5) {
                        Image(systemName: scoreInfo.matched ? "checkmark.circle.fill" : "brain.head.profile")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(scoreInfo.matched ? Color.green : AppTheme.navy)

                        let labelPrefix = scoreInfo.predictedLabel.isEmpty ? "" : "[\(scoreInfo.predictedLabel.capitalized)] "
                        Text("OpenJev \(labelPrefix)\(String(format: "%.2f", scoreInfo.score)) / \(String(format: "%.2f", scoreInfo.threshold))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(scoreInfo.matched ? Color.green : AppTheme.navy)

                        Text(scoreInfo.matched ? "• Gate Triggered" : "• Inactive")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(scoreInfo.matched ? Color.green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreInfo.matched ? Color.green.opacity(0.12) : Color(.systemGray6))
                    .cornerRadius(6)
                }

                Spacer()

                Text("\(currentText.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundColor(currentText.count > maxLength ? .red : .secondary)
            }
        }
        .padding()
        .background(AppTheme.pureWhite)
        .cornerRadius(12)
        .onChange(of: isFocused) { oldValue, newValue in
            if oldValue && !newValue {
                onBlur?(currentText)
            }
        }
    }

    private var currentText: String {
        if case .string(let s) = answer { return s }
        return ""
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { self.currentText },
            set: { val in
                if val.count <= maxLength {
                    self.answer = .string(val)
                    self.onTextChanged?(val)
                }
            }
        )
    }
}
