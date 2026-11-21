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

    public init(
        permissionManager: PermissionManagerProtocol,
        repository: SurveyRepositoryProtocol
    ) {
        self.permissionManager = permissionManager
        self.repository = repository

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

            await MainActor.run {
                self.statusMessage = "Device registered: \(response.status)"
                self.hasCompletedOnboarding = true
                self.isRegisteringDevice = false
            }
        } catch {
            await MainActor.run {
                self.isRegisteringDevice = false
                self.statusMessage = nil
                self.errorMessage = "Device registration failed: \(error.localizedDescription). Please verify your connection."
            }
        }
    }

    /// Retrieves cached APNs device token or generates a persistent anonymous UUID device identifier
    private func getOrCreateAnonymousDeviceToken() -> String {
        if let token = UserDefaults.standard.string(forKey: "apnsDeviceToken"), !token.isEmpty {
            return token
        }
        if let existing = UserDefaults.standard.string(forKey: "anonymousDeviceToken"), !existing.isEmpty {
            return existing
        }
        let generated = "device_\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(generated, forKey: "anonymousDeviceToken")
        return generated
    }
}
