import UIKit
import UserNotifications

public extension Notification.Name {
    static let openSurveyFromNotification = Notification.Name("openSurveyFromNotification")
    static let surveyPromptReceived = Notification.Name("surveyPromptReceived")
    static let deviceRegisteredSuccessfully = Notification.Name("deviceRegisteredSuccessfully")
}

public final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let apiClient: APIClientProtocol = APIClient(baseURL: AppConfiguration.apiBaseURL)

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Handle launch from notification if user launched app by tapping a notification
        if let notificationPayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            processNotificationUserInfo(notificationPayload, autoOpen: true)
        }

        return true
    }

    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        // Always cache the APNs token
        UserDefaults.standard.set(tokenString, forKey: "cachedAPNsDeviceToken")
        UserDefaults.standard.set(tokenString, forKey: "anonymousDeviceToken")

        // Per requirement: only register with backend after Terms & Conditions have been accepted!
        let termsAccepted = UserDefaults.standard.bool(forKey: "hasAcceptedTerms")
        guard termsAccepted else {
            return
        }

        // Post anonymous device token to backend
        Task {
            let payload = DeviceRegistration(
                deviceToken: tokenString,
                platform: .ios,
                timezone: TimeZone.current.identifier,
                registeredAt: Date()
            )

            do {
                let response: DeviceRegistrationResponse = try await apiClient.post("/api/notifications/devices", body: payload)
                UserDefaults.standard.set(true, forKey: "isDeviceRegistered")
                NotificationCenter.default.post(name: .deviceRegisteredSuccessfully, object: nil, userInfo: ["device_token": response.deviceToken])
            } catch {
                // Will retry upon next app launch or network reconnect
            }
        }
    }

    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Fallback: If APNs registration fails (e.g. simulator), ensure an anonymous token exists
        let currentToken = UserDefaults.standard.string(forKey: "anonymousDeviceToken")
        if currentToken == nil {
            let simToken = "anon_sim_\(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: ""))"
            UserDefaults.standard.set(simToken, forKey: "anonymousDeviceToken")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handles foreground notifications: displays banner, sound, badge, and notifies HomeViewModel
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        processNotificationUserInfo(userInfo, autoOpen: false)
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Handles banner or notification tap by the participant: routes into the survey during its window
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        processNotificationUserInfo(userInfo, autoOpen: true)
    }

    // MARK: - Private Helpers

    private func processNotificationUserInfo(_ userInfo: [AnyHashable: Any], autoOpen: Bool) {
        guard let surveyId = userInfo["survey_id"] as? String else { return }

        let sentAtString = userInfo["notification_sent_at"] as? String
        let isoFormatter = ISO8601DateFormatter()
        let sentAtDate = sentAtString.flatMap { isoFormatter.date(from: $0) } ?? Date()
        let timeToComplete = (userInfo["time_to_complete_minutes"] as? Int) ?? AppConfiguration.defaultTimeToCompleteMinutes

        let notificationName: Notification.Name = autoOpen ? .openSurveyFromNotification : .surveyPromptReceived

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: notificationName,
                object: nil,
                userInfo: [
                    "survey_id": surveyId,
                    "notification_sent_at": sentAtDate,
                    "time_to_complete_minutes": timeToComplete
                ]
            )
        }
    }
}
