import Foundation

/// Encapsulates the score, label, and matching status of a semantic gating evaluation.
public struct GatingEvaluationScore: Equatable, Sendable {
    public let score: Double
    public let threshold: Double
    public let matched: Bool
    public let condition: String
    public let predictedLabel: String

    nonisolated public init(
        score: Double,
        threshold: Double,
        matched: Bool,
        condition: String,
        predictedLabel: String = ""
    ) {
        self.score = score
        self.threshold = threshold
        self.matched = matched
        self.condition = condition
        self.predictedLabel = predictedLabel
    }
}

public protocol OnDeviceGatingServiceProtocol: Sendable {
    func evaluateCondition(
        condition: String?,
        answerText: String,
        threshold: Double
    ) async -> Bool

    func evaluateConditionWithScore(
        condition: String?,
        answerText: String,
        threshold: Double
    ) async -> GatingEvaluationScore

    func evaluateRule(
        rule: QuestionGatingRule,
        answer: AnyCodableValue?
    ) async -> Bool

    func evaluateRuleWithScore(
        rule: QuestionGatingRule,
        answer: AnyCodableValue?
    ) async -> GatingEvaluationScore
}
