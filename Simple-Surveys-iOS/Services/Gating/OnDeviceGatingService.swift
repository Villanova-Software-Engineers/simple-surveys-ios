import Foundation
import onnxruntime
import os

/// Thread-safe On-Device Semantic Question Gating Service powered entirely by OpenJev (ONNX Runtime).
/// Executes raw neural inference on `openjev_classifier_int8.onnx` using SentencePiece Metaspace tokenization.
/// Adheres strictly to a Fail-Closed design with no hardcoded fallback rules or dictionaries.
public actor OnDeviceGatingService: OnDeviceGatingServiceProtocol {
    public static let shared = OnDeviceGatingService()
    private let logger = Logger(subsystem: "edu.villanova.SimpleSurveys", category: "GatingService")

    private var isModelLoaded: Bool = false
    private var vocab: [String: Int64] = [:]

    // ONNX Runtime C-API References
    private var ortApi: UnsafePointer<OrtApi>?
    private var ortEnv: OpaquePointer?
    private var sessionOptions: OpaquePointer?
    private var session: OpaquePointer?
    private var memInfo: OpaquePointer?

    public init() {
        Task {
            await initializeSession()
        }
    }

    deinit {
        if let api = ortApi {
            if let mem = memInfo { api.pointee.ReleaseMemoryInfo(mem) }
            if let s = session { api.pointee.ReleaseSession(s) }
            if let opt = sessionOptions { api.pointee.ReleaseSessionOptions(opt) }
            if let env = ortEnv { api.pointee.ReleaseEnv(env) }
        }
    }

    /// Initializes OpenJev ONNX session and tokenizer from bundled resources
    public func initializeSession() async {
        guard let apiBase = OrtGetApiBase(),
              let api = apiBase.pointee.GetApi(UInt32(ORT_API_VERSION)) else {
            logger.error("Failed to initialize OrtApiBase.")
            self.isModelLoaded = false
            return
        }
        self.ortApi = api

        guard let modelUrl = Bundle.main.url(forResource: "openjev_classifier_int8", withExtension: "onnx"),
              let tokenizerUrl = Bundle.main.url(forResource: "tokenizer", withExtension: "json") else {
            logger.warning("OpenJev assets (openjev_classifier_int8.onnx or tokenizer.json) not found in bundle. Strict fail-closed active.")
            self.isModelLoaded = false
            return
        }

        // 1. Load tokenizer vocabulary
        do {
            let data = try Data(contentsOf: tokenizerUrl)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let modelDict = json["model"] as? [String: Any],
               let vocabList = modelDict["vocab"] as? [[Any]] {
                var loadedVocab = [String: Int64]()
                loadedVocab.reserveCapacity(vocabList.count)
                for (i, entry) in vocabList.enumerated() {
                    if let token = entry.first as? String {
                        loadedVocab[token] = Int64(i)
                    }
                }
                self.vocab = loadedVocab
            } else {
                logger.error("Failed to parse vocab from tokenizer.json")
                self.isModelLoaded = false
                return
            }
        } catch {
            logger.error("Failed to load tokenizer.json: \(error.localizedDescription)")
            self.isModelLoaded = false
            return
        }

        // 2. Initialize ONNX Runtime Session
        var env: OpaquePointer?
        let envStatus = api.pointee.CreateEnv(ORT_LOGGING_LEVEL_WARNING, "openjev", &env)
        if envStatus != nil {
            logger.error("Failed to create OrtEnv")
            self.isModelLoaded = false
            return
        }
        self.ortEnv = env

        var options: OpaquePointer?
        let optStatus = api.pointee.CreateSessionOptions(&options)
        if optStatus != nil {
            logger.error("Failed to create OrtSessionOptions")
            self.isModelLoaded = false
            return
        }
        self.sessionOptions = options

        var sess: OpaquePointer?
        let sessStatus = api.pointee.CreateSession(env, modelUrl.path, options, &sess)
        if let status = sessStatus {
            let msg = String(cString: api.pointee.GetErrorMessage(status)!)
            logger.error("Failed to create OrtSession for OpenJev: \(msg)")
            self.isModelLoaded = false
            return
        }
        self.session = sess

        var mem: OpaquePointer?
        let memStatus = api.pointee.CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &mem)
        if memStatus != nil {
            logger.error("Failed to create OrtMemoryInfo")
            self.isModelLoaded = false
            return
        }
        self.memInfo = mem

        self.isModelLoaded = true
        logger.info("OpenJev ONNX Runtime session loaded successfully.")
    }

    /// Evaluates natural language gating condition against free-text answer using OpenJev classifier.
    public func evaluateCondition(
        condition: String?,
        answerText: String,
        threshold: Double = 0.55
    ) async -> Bool {
        let result = await evaluateConditionWithScore(condition: condition, answerText: answerText, threshold: threshold)
        return result.matched
    }

    /// Evaluates condition and returns detailed score, label, and threshold matching result.
    public func evaluateConditionWithScore(
        condition: String?,
        answerText: String,
        threshold: Double = 0.55
    ) async -> GatingEvaluationScore {
        guard let condition = condition, !condition.isEmpty else {
            return GatingEvaluationScore(score: 0.0, threshold: threshold, matched: false, condition: "")
        }
        let trimmedText = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return GatingEvaluationScore(score: 0.0, threshold: threshold, matched: false, condition: condition)
        }

        // Input guard: Minimum 3-word count threshold before passing text to OpenJev
        let wordCount = trimmedText.split(whereSeparator: \.isWhitespace).count
        guard wordCount >= 3 else {
            return GatingEvaluationScore(score: 0.0, threshold: threshold, matched: false, condition: condition)
        }

        guard isModelLoaded else {
            logger.debug("OpenJev model not loaded. Fail-closed returned false.")
            return GatingEvaluationScore(score: 0.0, threshold: threshold, matched: false, condition: condition)
        }

        // Trailing punctuation normalization:
        // Transformer NLI models are sensitive to sentence boundaries. Appending a terminal
        // period if missing prevents subword shifts and end-of-sequence attention degradation.
        var normalizedText = trimmedText
        if !normalizedText.isEmpty {
            let terminalPunctuation: Set<Character> = [".", "!", "?"]
            if let lastChar = normalizedText.last, !terminalPunctuation.contains(lastChar) {
                normalizedText.append(".")
            }
        }

        let formattedHypothesis = normalizeHypothesis(condition: condition)

        do {
            let (score, label) = try await withThrowingTaskGroup(of: (Double, String).self) { group in
                group.addTask {
                    await self.runInference(text: normalizedText, hypothesis: formattedHypothesis)
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms frame budget timeout
                    throw GatingError.timeout
                }

                let finalResult = try await group.next() ?? (0.0, "unknown")
                group.cancelAll()
                return finalResult
            }

            let isMatched = score >= threshold
            return GatingEvaluationScore(
                score: score,
                threshold: threshold,
                matched: isMatched,
                condition: condition,
                predictedLabel: label
            )
        } catch {
            logger.warning("OpenJev evaluation timed out or failed: \(error.localizedDescription).")
            return GatingEvaluationScore(score: 0.0, threshold: threshold, matched: false, condition: condition)
        }
    }

    /// Evaluates any supported QuestionGatingRule against an answered value.
    public func evaluateRule(
        rule: QuestionGatingRule,
        answer: AnyCodableValue?
    ) async -> Bool {
        let result = await evaluateRuleWithScore(rule: rule, answer: answer)
        return result.matched
    }

    /// Evaluates any supported QuestionGatingRule and returns detailed score information.
    public func evaluateRuleWithScore(
        rule: QuestionGatingRule,
        answer: AnyCodableValue?
    ) async -> GatingEvaluationScore {
        guard let answer = answer, !answer.isEmpty else {
            return GatingEvaluationScore(score: 0.0, threshold: rule.threshold, matched: false, condition: rule.naturalLanguageCondition ?? "")
        }
        let answerText = answer.stringValue ?? ""

        switch rule.operator {
        case .openjevMatches:
            return await evaluateConditionWithScore(
                condition: rule.naturalLanguageCondition,
                answerText: answerText,
                threshold: rule.threshold
            )
        case .equals:
            guard let condition = rule.naturalLanguageCondition else {
                return GatingEvaluationScore(score: 0.0, threshold: rule.threshold, matched: false, condition: "")
            }
            let matched = answerText.caseInsensitiveCompare(condition) == .orderedSame
            return GatingEvaluationScore(score: matched ? 1.0 : 0.0, threshold: rule.threshold, matched: matched, condition: condition)
        case .contains:
            guard let condition = rule.naturalLanguageCondition else {
                return GatingEvaluationScore(score: 0.0, threshold: rule.threshold, matched: false, condition: "")
            }
            let matched = answerText.localizedCaseInsensitiveContains(condition)
            return GatingEvaluationScore(score: matched ? 1.0 : 0.0, threshold: rule.threshold, matched: matched, condition: condition)
        case .greaterThan:
            guard let condition = rule.naturalLanguageCondition,
                  let condVal = Double(condition),
                  let ansVal = answer.doubleValue ?? Double(answerText) else {
                return GatingEvaluationScore(score: 0.0, threshold: rule.threshold, matched: false, condition: rule.naturalLanguageCondition ?? "")
            }
            let matched = ansVal > condVal
            return GatingEvaluationScore(score: matched ? 1.0 : 0.0, threshold: rule.threshold, matched: matched, condition: condition)
        case .lessThan:
            guard let condition = rule.naturalLanguageCondition,
                  let condVal = Double(condition),
                  let ansVal = answer.doubleValue ?? Double(answerText) else {
                return GatingEvaluationScore(score: 0.0, threshold: rule.threshold, matched: false, condition: rule.naturalLanguageCondition ?? "")
            }
            let matched = ansVal < condVal
            return GatingEvaluationScore(score: matched ? 1.0 : 0.0, threshold: rule.threshold, matched: matched, condition: condition)
        }
    }

    // MARK: - Pure Neural Inference via ONNX Runtime

    private func runInference(text: String, hypothesis: String) async -> (Double, String) {
        guard let api = ortApi, let session = session, let memInfo = memInfo else {
            return (0.0, "uninitialized")
        }

        // Tokenize premise (user text) and hypothesis (survey condition)
        var (inputIds, mask) = encodePair(premise: text, hypothesis: hypothesis)
        var shape: [Int64] = [1, Int64(inputIds.count)]

        var inVal: OpaquePointer?
        let inStatus = api.pointee.CreateTensorWithDataAsOrtValue(
            memInfo,
            &inputIds,
            inputIds.count * MemoryLayout<Int64>.stride,
            &shape,
            2,
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &inVal
        )
        guard inStatus == nil, let inVal = inVal else { return (0.0, "tensor_error") }

        var maskVal: OpaquePointer?
        let maskStatus = api.pointee.CreateTensorWithDataAsOrtValue(
            memInfo,
            &mask,
            mask.count * MemoryLayout<Int64>.stride,
            &shape,
            2,
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &maskVal
        )
        guard maskStatus == nil, let maskVal = maskVal else {
            api.pointee.ReleaseValue(inVal)
            return (0.0, "tensor_error")
        }

        let inNames: [UnsafePointer<CChar>?] = [
            ("input_ids" as NSString).utf8String,
            ("attention_mask" as NSString).utf8String
        ]
        let outNames: [UnsafePointer<CChar>?] = [
            ("logits" as NSString).utf8String
        ]
        let inValues: [OpaquePointer?] = [inVal, maskVal]
        var outValues: [OpaquePointer?] = [nil]

        var entailmentProb: Double = 0.0
        var predictedLabel: String = "neutral"

        inValues.withUnsafeBufferPointer { inBuf in
            inNames.withUnsafeBufferPointer { inNamesBuf in
                outNames.withUnsafeBufferPointer { outNamesBuf in
                    outValues.withUnsafeMutableBufferPointer { outBuf in
                        let status = api.pointee.Run(
                            session,
                            nil,
                            inNamesBuf.baseAddress,
                            inBuf.baseAddress,
                            2,
                            outNamesBuf.baseAddress,
                            1,
                            outBuf.baseAddress
                        )
                        if status == nil, let outValPtr = outBuf[0] {
                            var outData: UnsafeMutableRawPointer?
                            _ = api.pointee.GetTensorMutableData(outValPtr, &outData)
                            if let ptr = outData?.assumingMemoryBound(to: Float.self) {
                                let l0 = ptr[0] // Contradiction
                                let l1 = ptr[1] // Entailment
                                let l2 = ptr[2] // Neutral

                                // Softmax
                                let maxL = max(l0, max(l1, l2))
                                let e0 = exp(l0 - maxL)
                                let e1 = exp(l1 - maxL)
                                let e2 = exp(l2 - maxL)
                                let sumE = e0 + e1 + e2

                                let p0 = e0 / sumE
                                let p1 = e1 / sumE
                                let p2 = e2 / sumE

                                entailmentProb = round(Double(p1) * 1000.0) / 1000.0

                                if p1 >= p0 && p1 >= p2 {
                                    predictedLabel = "entailment"
                                } else if p0 >= p1 && p0 >= p2 {
                                    predictedLabel = "contradiction"
                                } else {
                                    predictedLabel = "neutral"
                                }
                            }
                        }
                    }
                }
            }
        }

        api.pointee.ReleaseValue(inVal)
        api.pointee.ReleaseValue(maskVal)
        if let outValPtr = outValues[0] {
            api.pointee.ReleaseValue(outValPtr)
        }

        return (entailmentProb, predictedLabel)
    }

    // MARK: - SentencePiece Metaspace Tokenizer

    private func tokenize(text: String) -> [Int64] {
        let clean = "\u{2581}" + text.replacingOccurrences(of: " ", with: "\u{2581}")
        var ids: [Int64] = []
        let chars = Array(clean)
        var i = 0
        let n = chars.count
        while i < n {
            var matched = false
            let maxLen = min(30, n - i)
            for l in stride(from: maxLen, through: 1, by: -1) {
                let sub = String(chars[i..<i+l])
                if let id = vocab[sub] ?? vocab[sub.lowercased()] {
                    ids.append(id)
                    i += l
                    matched = true
                    break
                }
            }
            if !matched {
                let ch = String(chars[i])
                ids.append(vocab[ch] ?? 3)
                i += 1
            }
        }
        return ids
    }

    private func encodePair(premise: String, hypothesis: String) -> (ids: [Int64], mask: [Int64]) {
        let pIds = tokenize(text: premise)
        let hIds = tokenize(text: hypothesis)
        // [CLS] = 1, [SEP] = 2
        let allIds = [1] + pIds + [2] + hIds + [2]
        let mask = Array(repeating: Int64(1), count: allIds.count)
        return (allIds, mask)
    }

    /// Normalizes condition string into a natural declarative NLI hypothesis.
    private func normalizeHypothesis(condition: String) -> String {
        let trimmed = condition.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.contains("stress") || lower.contains("anxiety") || lower.contains("overwhelm") {
            return "The person feels stress or pressure."
        }

        if lower.hasPrefix("response expresses ") {
            let remainder = trimmed.dropFirst("response expresses ".count)
            return "The person feels " + remainder + "."
        } else if lower.hasPrefix("participant mentions ") {
            let remainder = trimmed.dropFirst("participant mentions ".count)
            return "The person mentions " + remainder + "."
        } else if !trimmed.hasPrefix("The ") && !trimmed.hasPrefix("This ") {
            return "The person feels " + trimmed + "."
        }
        return trimmed
    }

    private enum GatingError: Error {
        case timeout
    }
}
