import Foundation
import UserNotifications

public protocol NotificationSchedulerProtocol: AnyObject, Sendable {
    func scheduleDailyNotifications() async throws -> [ScheduledDispatchInfo]
    func scheduleTestPrompt(surveyId: String?, delaySeconds: TimeInterval) async throws -> ScheduledDispatchInfo
    func cancelScheduledPrompts() async
}
