import PushKit
import UIKit
import UserNotifications

final class RotaryAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency PKPushRegistryDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    private let voipRegistry = PKPushRegistry(queue: .main)
    private let voiceCoordinator = VoiceCoordinator.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !ProcessInfo.isRunningRotaryUnitTests else {
            return true
        }

        UNUserNotificationCenter.current().delegate = self
        registerForRemoteNotificationsIfAuthorized(using: application)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        _ = application
        _ = window
        return .portrait
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        _ = application
        Task { await voiceCoordinator.updatePushCredentials(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        _ = application
        Task { @MainActor in
            voiceCoordinator.lastError = "Standard push registration failed: \(error.localizedDescription)"
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        Task { await voiceCoordinator.updateVoipCredentials(credentials) }
        _ = registry
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        voiceCoordinator.invalidateVoipToken()
        _ = registry
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        guard type == .voIP else { return }
        voiceCoordinator.handleIncomingPush(payload: payload)
        _ = registry
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }
        voiceCoordinator.handleIncomingPush(payload: payload, completion: completion)
        _ = registry
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        _ = center
        _ = notification
        return [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        _ = center
        routeNotificationPayload(response.notification.request.content.userInfo)
    }

    private func registerForRemoteNotificationsIfAuthorized(using application: UIApplication) {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let isAuthorized: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isAuthorized = true
            default:
                isAuthorized = false
            }

            guard isAuthorized else { return }
            await MainActor.run {
                application.registerForRemoteNotifications()
            }
        }
    }

    private func routeNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        let deepLinkString = userInfo["deep_link"] as? String ?? userInfo["url"] as? String
        guard let deepLinkString,
              let url = URL(string: deepLinkString) else {
            return
        }

        Task { @MainActor in
            UIApplication.shared.open(url)
        }
    }
}
