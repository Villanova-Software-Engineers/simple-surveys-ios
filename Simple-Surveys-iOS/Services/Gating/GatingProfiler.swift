import Foundation

public actor GatingProfiler {
    public static func measureInference(
        condition: String,
        text: String,
        evaluator: OnDeviceGatingServiceProtocol
    ) async -> (result: Bool, latencyMs: Double) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await evaluator.evaluateCondition(
            condition: condition,
            answerText: text,
            threshold: 0.55
        )
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        #if DEBUG
        print(String(format: "[OpenJev Profiler] Latency: %.2f ms | Result: %@", elapsedMs, result ? "TRUE" : "FALSE"))
        #endif

        return (result, elapsedMs)
    }
}
