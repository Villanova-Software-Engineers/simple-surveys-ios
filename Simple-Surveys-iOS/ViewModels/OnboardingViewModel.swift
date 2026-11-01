import SwiftUI
import Observation

@Observable
public final class OnboardingViewModel {
    public var isTermsAccepted: Bool = false
    public var isRequesting: Bool = false
    public var isRegisteringDevice: Bool = false
    public var errorMessage: String?
    public var statusMessage: String?
    public var hasCompletedOnboarding: Bool = false
    public var showingTermsSheet: Bool = false

    private let permissionManager: PermissionManagerProtocol
    private let repository: SurveyRepositoryProtocol
    private let scheduler: NotificationSchedulerProtocol?

    public init(
        permissionManager: PermissionManagerProtocol,
        repository: SurveyRepositoryProtocol,
        scheduler: NotificationSchedulerProtocol? = nil
    ) {
        self.permissionManager = permissionManager
        self.repository = repository
        self.scheduler = scheduler

        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.isTermsAccepted = UserDefaults.standard.bool(forKey: "hasAcceptedTerms")
    }

    /// Toggles acceptance of study Terms and Conditions
    public func toggleTermsAcceptance() {
        isTermsAccepted.toggle()
        if isTermsAccepted {
            errorMessage = nil
        }
    }

    /// Primary onboarding action: verifies terms acceptance, requests permissions, and registers anonymous device with backend
    public func acceptTermsAndRegisterDevice() async {
        guard isTermsAccepted else {
            errorMessage = "You must read and accept the Terms & Conditions and Informed Consent to participate."
            return
        }

        isRequesting = true
        errorMessage = nil
        statusMessage = "Requesting permissions..."

        // 1. Mark terms accepted in storage
        UserDefaults.standard.set(true, forKey: "hasAcceptedTerms")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "termsAcceptedAt")

        // 2. Request all three required permissions (Push Notifications, Location, Camera)
        let permissionsGranted = await permissionManager.requestAllPermissions()
        guard permissionsGranted else {
            isRequesting = false
            statusMessage = nil
            errorMessage = "All permissions (Push Notifications, Location, and Camera) are required for experience sampling. Please enable them to continue."
            return
        }

        // 3. Register anonymous device token with the backend
        await registerAnonymousDevice()
        isRequesting = false
    }

    /// Registers the anonymous device token with POST /api/notifications/devices
    public func registerAnonymousDevice() async {
        isRegisteringDevice = true
        errorMessage = nil
        statusMessage = "Registering anonymous device with server..."

        // Obtain APNs token or generate persistent anonymous device UUID
        let token = getOrCreateAnonymousDeviceToken()
        let timezone = TimeZone.current.identifier

        do {
            let response = try await repository.registerDevice(token: token, timezone: timezone)
            
            // Mark registration and onboarding complete
            UserDefaults.standard.set(true, forKey: "isDeviceRegistered")
            UserDefaults.standard.set(token, forKey: "registeredDeviceToken")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

            // Initialize daily notification schedule
            if let scheduler = scheduler {
                statusMessage = "Scheduling daily survey prompts..."
                _ = try? await scheduler.scheduleDailyNotifications()
            }

            await MainActor.run {
                self.statusMessage = "Device registered: \(response.status)"
                self.hasCompletedOnboarding = true
                self.isRegisteringDevice = false
            }
        } catch {
            await MainActor.run {
                self.isRegisteringDevice = false
                self.statusMessage = nil
                self.errorMessage = "Failed to register anonymous device with server: \(error.localizedDescription). Please verify your backend server connection."
            }
        }
    }

    // MARK: - Private Token Management

    private func getOrCreateAnonymousDeviceToken() -> String {
        if let apnsToken = UserDefaults.standard.string(forKey: "cachedAPNsDeviceToken"), !apnsToken.isEmpty {
            return apnsToken
        }
        if let existingAnon = UserDefaults.standard.string(forKey: "anonymousDeviceToken"), !existingAnon.isEmpty {
            return existingAnon
        }
        let newToken = "anon_\(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: ""))"
        UserDefaults.standard.set(newToken, forKey: "anonymousDeviceToken")
        return newToken
    }
}
