import SwiftUI

/// Generic schema-driven dynamic survey renderer.
/// Renders questions by type (rating_scale, single_choice, multiple_choice, text, numeric)
/// and reacts to on-device semantic gating visibility maps with top-edge move and opacity transitions.
public struct DynamicSurveyView: View {
    public let questions: [QuestionConfig]
    @Binding public var answers: [String: AnyCodableValue]
    public let gatingVisibilityMap: [String: Bool]
    public let gatingScores: [String: GatingEvaluationScore]
    public var onTextChanged: ((String, String) -> Void)?
    public var onTextBlur: ((String, String) -> Void)?

    public init(
        questions: [QuestionConfig],
        answers: Binding<[String: AnyCodableValue]>,
        gatingVisibilityMap: [String: Bool],
        gatingScores: [String: GatingEvaluationScore] = [:],
        onTextChanged: ((String, String) -> Void)? = nil,
        onTextBlur: ((String, String) -> Void)? = nil
    ) {
        self.questions = questions
        self._answers = answers
        self.gatingVisibilityMap = gatingVisibilityMap
        self.gatingScores = gatingScores
        self.onTextChanged = onTextChanged
        self.onTextBlur = onTextBlur
    }

    public var body: some View {
        VStack(spacing: 16) {
            ForEach(questions, id: \.questionId) { question in
                let isVisible = gatingVisibilityMap[question.questionId] ?? (question.gatingRule == nil)
                if isVisible {
                    QuestionCardView(
                        question: question,
                        value: Binding(
                            get: { answers[question.questionId] },
                            set: { newValue in
                                if let newValue = newValue {
                                    answers[question.questionId] = newValue
                                } else {
                                    answers.removeValue(forKey: question.questionId)
                                }
                            }
                        ),
                        gatingScoreInfo: gatingScores[question.questionId],
                        onTextChanged: onTextChanged,
                        onTextBlur: onTextBlur
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: gatingVisibilityMap)
    }
}

public struct QuestionCardView: View {
    public let question: QuestionConfig
    @Binding public var value: AnyCodableValue?
    public var gatingScoreInfo: GatingEvaluationScore?
    public var onTextChanged: ((String, String) -> Void)?
    public var onTextBlur: ((String, String) -> Void)?

    public init(
        question: QuestionConfig,
        value: Binding<AnyCodableValue?>,
        gatingScoreInfo: GatingEvaluationScore? = nil,
        onTextChanged: ((String, String) -> Void)? = nil,
        onTextBlur: ((String, String) -> Void)? = nil
    ) {
        self.question = question
        self._value = value
        self.gatingScoreInfo = gatingScoreInfo
        self.onTextChanged = onTextChanged
        self.onTextBlur = onTextBlur
    }

    public var body: some View {
        Group {
            switch question.type {
            case .ratingScale:
                RatingScaleQuestionView(question: question, answer: $value)
            case .singleChoice:
                SingleChoiceQuestionView(question: question, answer: $value)
            case .multipleChoice:
                MultipleChoiceQuestionView(question: question, answer: $value)
            case .text:
                TextQuestionView(
                    question: question,
                    answer: $value,
                    onTextChanged: { newText in
                        onTextChanged?(question.questionId, newText)
                    },
                    onBlur: { text in
                        onTextBlur?(question.questionId, text)
                    },
                    gatingScoreInfo: gatingScoreInfo
                )
            case .numeric:
                NumericQuestionView(question: question, answer: $value)
            }
        }
    }
}
