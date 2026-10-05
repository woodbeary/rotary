import AVFAudio
import Contacts
import UIKit
import UserNotifications

@MainActor
final class RotaryPermissionCenter {
    static let shared = RotaryPermissionCenter()

    private let contactStore = CNContactStore()

    func currentStatus() async -> PermissionGateStatus {
        PermissionGateStatus(
            notifications: await notificationStatus(),
            microphone: microphoneStatus(),
            contacts: contactsStatus()
        )
    }

    func requestPermission(for step: PermissionGateStep) async -> PermissionAuthorizationStatus {
        switch step {
        case .notifications:
            return await requestNotificationsPermission()
        case .microphone:
            return await requestMicrophonePermission()
        case .contacts:
            return await requestContactsPermission()
        }
    }

    func requestRequiredPermissions() async -> PermissionGateStatus {
        _ = await requestNotificationsPermission()
        _ = await requestMicrophonePermission()
        return await currentStatus()
    }

    func requestNotificationsPermission() async -> PermissionAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Keep the current state when the request throws.
        }
        return await notificationStatus()
    }

    func requestMicrophonePermission() async -> PermissionAuthorizationStatus {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { accepted in
                        continuation.resume(returning: accepted)
                    }
                }
                return granted ? .authorized : .denied
            @unknown default:
                return .restricted
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    session.requestRecordPermission { accepted in
                        continuation.resume(returning: accepted)
                    }
                }
                return granted ? .authorized : .denied
            @unknown default:
                return .restricted
            }
        }
    }

    func requestContactsPermission() async -> PermissionAuthorizationStatus {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func notificationStatus() async -> PermissionAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .restricted
        }
    }

    private func microphoneStatus() -> PermissionAuthorizationStatus {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .restricted
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .restricted
            }
        }
    }

    private func contactsStatus() -> PermissionAuthorizationStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return .authorized
        case .limited:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .restricted
        }
    }
}
