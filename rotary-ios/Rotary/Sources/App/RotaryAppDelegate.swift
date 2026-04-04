import PushKit
import UIKit

final class RotaryAppDelegate: NSObject, @preconcurrency UIApplicationDelegate, @preconcurrency PKPushRegistryDelegate {
    private let voipRegistry = PKPushRegistry(queue: .main)
    private let voiceCoordinator = VoiceCoordinator.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !ProcessInfo.isRunningRotaryUnitTests else {
            return true
        }
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
}
