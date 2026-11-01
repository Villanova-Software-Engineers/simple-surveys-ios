import Foundation
import UserNotifications

public final class NotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    private let repository: SurveyRepositoryProtocol
    private let notificationCenter: UNUserNotificationCenter

    public init(
        repository: SurveyRepositoryProtocol,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
    }

    /// Fetches the backend sampling configuration and schedules today's daily notification prompts
    public func scheduleDailyNotifications() async throws -> [ScheduledDispatchInfo] {
        let rules = try await repository.fetchScheduleConfig()
        let surveys = try? await repository.listSurveys()
        let surveyMap: [String: SurveyConfig] = Dictionary(
            uniqueKeysWithValues: (surveys ?? []).map { ($0.surveyId, $0) }
        )

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        var dispatches: [ScheduledDispatchInfo] = []

        // 1. Overall window bounds
        guard let overallStart = combine(date: today, timeString: rules.dailySchedule.overallWindow.startTime),
              let overallEnd = combine(date: today, timeString: rules.dailySchedule.overallWindow.endTime) else {
            return []
        }

        // 2. First window bounds
        let firstWinStart = combine(date: today, timeString: rules.dailySchedule.firstWindow.startTime) ?? overallStart
        let firstWinEnd = combine(date: today, timeString: rules.dailySchedule.firstWindow.endTime) ?? overallStart.addingTimeInterval(5400)

        // 3. Last window bounds
        let lastWinStart = combine(date: today, timeString: rules.dailySchedule.lastWindow.startTime) ?? overallEnd.addingTimeInterval(-5400)
        let lastWinEnd = combine(date: today, timeString: rules.dailySchedule.lastWindow.endTime) ?? overallEnd

        var firstDispatchDate: Date?
        var lastDispatchDate: Date?

        // 4. Fixed survey dispatches (first, last, or explicit scheduled_time)
        if rules.mode == .hybrid || rules.mode == .allFixed {
            for fixed in rules.fixedSurveys {
                let survey = surveyMap[fixed.surveyId]
                let title = survey?.notificationPrompt?.title ?? survey?.title ?? "Survey Check-In"
                let body = survey?.notificationPrompt?.body ?? "Time for your scheduled survey prompt. You have \(rules.timeToCompleteMinutes) minutes to respond."

                if fixed.position == "first" {
                    let dispatchDt: Date
                    if let schedTime = fixed.scheduledTime, let explicit = combine(date: today, timeString: schedTime) {
                        dispatchDt = explicit
                    } else {
                        dispatchDt = randomTimeBetween(start: firstWinStart, end: firstWinEnd)
                    }
                    firstDispatchDate = dispatchDt
                    dispatches.append(
                        ScheduledDispatchInfo(
                            surveyId: fixed.surveyId,
                            dispatchTime: dispatchDt,
                            isFixed: true,
                            position: "first",
                            promptTitle: title,
                            promptBody: body
                        )
                    )
                } else if fixed.position == "last" {
                    let dispatchDt: Date
                    if let schedTime = fixed.scheduledTime, let explicit = combine(date: today, timeString: schedTime) {
                        dispatchDt = explicit
                    } else {
                        dispatchDt = randomTimeBetween(start: lastWinStart, end: lastWinEnd)
                    }
                    lastDispatchDate = dispatchDt
                    dispatches.append(
                        ScheduledDispatchInfo(
                            surveyId: fixed.surveyId,
                            dispatchTime: dispatchDt,
                            isFixed: true,
                            position: "last",
                            promptTitle: title,
                            promptBody: body
                        )
                    )
                } else if let schedTime = fixed.scheduledTime, let explicit = combine(date: today, timeString: schedTime) {
                    dispatches.append(
                        ScheduledDispatchInfo(
                            surveyId: fixed.surveyId,
                            dispatchTime: explicit,
                            isFixed: true,
                            position: nil,
                            promptTitle: title,
                            promptBody: body
                        )
                    )
                }
            }
        }

        // 5. Intraday randomized sampling
        if rules.mode == .hybrid || rules.mode == .allRandom {
            let randStart = firstDispatchDate ?? overallStart
            let randEnd = lastDispatchDate ?? overallEnd
            let count = rules.randomizedSampling.promptsPerDay
            let minInterval = TimeInterval(rules.randomizedSampling.minIntervalMinutes * 60)
            let eligibleIds = rules.randomizedSampling.eligibleSurveyIds

            if randEnd > randStart.addingTimeInterval(minInterval) && count > 0 && !eligibleIds.isEmpty {
                let sampledDates = sampleIntradaySlots(
                    start: randStart,
                    end: randEnd,
                    count: count,
                    minInterval: minInterval
                )

                for (idx, slotDate) in sampledDates.enumerated() {
                    let pickedSurveyId = eligibleIds[idx % eligibleIds.count]
                    let survey = surveyMap[pickedSurveyId]
                    let title = survey?.notificationPrompt?.title ?? survey?.title ?? "Quick Survey Check-In"
                    let body = survey?.notificationPrompt?.body ?? "Time for your scheduled experience sampling survey."

                    dispatches.append(
                        ScheduledDispatchInfo(
                            surveyId: pickedSurveyId,
                            dispatchTime: slotDate,
                            isFixed: false,
                            position: nil,
                            promptTitle: title,
                            promptBody: body
                        )
                    )
                }
            }
        }

        dispatches.sort { $0.dispatchTime < $1.dispatchTime }

        // 6. Clear previously scheduled survey requests
        await cancelScheduledPrompts()

        // 7. Register requests with UNUserNotificationCenter for all dispatches later today
        let isoFormatter = ISO8601DateFormatter()
        for dispatch in dispatches {
            // Only schedule if time is in future
            guard dispatch.dispatchTime > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = dispatch.promptTitle
            content.body = dispatch.promptBody
            content.sound = .default
            content.categoryIdentifier = "SURVEY_PROMPT"
            content.userInfo = [
                "survey_id": dispatch.surveyId,
                "notification_sent_at": isoFormatter.string(from: dispatch.dispatchTime),
                "time_to_complete_minutes": rules.timeToCompleteMinutes
            ]

            let triggerComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: dispatch.dispatchTime
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "survey_prompt_\(dispatch.surveyId)_\(Int(dispatch.dispatchTime.timeIntervalSince1970))",
                content: content,
                trigger: trigger
            )

            try? await notificationCenter.add(request)
        }

        return dispatches
    }

    /// Schedules an immediate test notification prompt in `delaySeconds` for verification of window logic
    public func scheduleTestPrompt(
        surveyId: String? = nil,
        delaySeconds: TimeInterval = 5
    ) async throws -> ScheduledDispatchInfo {
        let rules = (try? await repository.fetchScheduleConfig()) ?? SamplingRules(
            dailySchedule: DailyScheduleWindows(
                overallWindow: TimeWindow(startTime: "08:00", endTime: "22:00"),
                firstWindow: TimeWindow(startTime: "08:00", endTime: "09:30"),
                lastWindow: TimeWindow(startTime: "20:30", endTime: "22:00")
            ),
            randomizedSampling: RandomizedSamplingConfig(promptsPerDay: 3, minIntervalMinutes: 60, eligibleSurveyIds: [])
        )

        let chosenSurveyId: String
        if let explicit = surveyId {
            chosenSurveyId = explicit
        } else if let firstFixed = rules.fixedSurveys.first {
            chosenSurveyId = firstFixed.surveyId
        } else if let firstEligible = rules.randomizedSampling.eligibleSurveyIds.first {
            chosenSurveyId = firstEligible
        } else {
            chosenSurveyId = "comprehensive_sample_survey"
        }

        let survey = try? await repository.fetchScheduledSurvey(id: chosenSurveyId)
        let title = survey?.notificationPrompt?.title ?? survey?.title ?? "Test Survey Prompt"
        let body = survey?.notificationPrompt?.body ?? "Your survey window is now open. You have \(rules.timeToCompleteMinutes) minutes to complete it."

        let dispatchDate = Date().addingTimeInterval(delaySeconds)
        let isoFormatter = ISO8601DateFormatter()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "SURVEY_PROMPT"
        content.userInfo = [
            "survey_id": chosenSurveyId,
            "notification_sent_at": isoFormatter.string(from: dispatchDate),
            "time_to_complete_minutes": rules.timeToCompleteMinutes
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_prompt_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)

        return ScheduledDispatchInfo(
            surveyId: chosenSurveyId,
            dispatchTime: dispatchDate,
            isFixed: true,
            position: "test",
            promptTitle: title,
            promptBody: body
        )
    }

    /// Cancels all pending survey prompts from UNUserNotificationCenter
    public func cancelScheduledPrompts() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let surveyPromptIds = pending
            .filter { $0.identifier.hasPrefix("survey_prompt_") || $0.identifier.hasPrefix("test_prompt_") }
            .map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: surveyPromptIds)
    }

    // MARK: - Helper Sampling Algorithms (Matching Backend Logic)

    private func combine(date: Date, timeString: String) -> Date? {
        let parts = timeString.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps)
    }

    private func randomTimeBetween(start: Date, end: Date) -> Date {
        let delta = end.timeIntervalSince(start)
        guard delta > 0 else { return start }
        let randomOffset = Double.random(in: 0...delta)
        return start.addingTimeInterval(randomOffset)
    }

    private func sampleIntradaySlots(
        start: Date,
        end: Date,
        count: Int,
        minInterval: TimeInterval
    ) -> [Date] {
        guard count > 0 else { return [] }
        let totalSpan = end.timeIntervalSince(start)

        // If span is too tight for strict minInterval, stratify evenly
        if totalSpan < Double(count + 1) * minInterval {
            let step = totalSpan / Double(count + 1)
            return (0..<count).map { start.addingTimeInterval(step * Double($0 + 1)) }
        }

        // Stratified sampling with random jitter
        let slotSize = totalSpan / Double(count)
        var results: [Date] = []
        var lastPicked = start

        for i in 0..<count {
            let subStart = start.addingTimeInterval(Double(i) * slotSize)
            let subEnd = start.addingTimeInterval(Double(i + 1) * slotSize)

            let earliest = max(subStart, lastPicked.addingTimeInterval(minInterval))
            let latest = subEnd.addingTimeInterval(-1)

            let picked: Date
            if earliest >= latest {
                picked = earliest
            } else {
                picked = randomTimeBetween(start: earliest, end: latest)
            }
            results.append(picked)
            lastPicked = picked
        }

        return results
    }
}
