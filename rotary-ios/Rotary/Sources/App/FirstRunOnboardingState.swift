import Foundation

enum PermissionGateStep: String, Codable, CaseIterable, Hashable, Identifiable {
    case notifications
    case microphone
    case contacts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications:
            return "Notifications"
        case .microphone:
            return "Microphone"
        case .contacts:
            return "Contacts"
        }
    }

    var isRequired: Bool {
        switch self {
        case .notifications, .microphone:
            return true
        case .contacts:
            return false
        }
    }
}

enum PermissionAuthorizationStatus: String, Codable, Hashable {
    case notDetermined
    case denied
    case restricted
    case authorized

    var isGranted: Bool {
        self == .authorized
    }
}

struct PermissionGateStatus: Codable, Hashable {
    var notifications: PermissionAuthorizationStatus
    var microphone: PermissionAuthorizationStatus
    var contacts: PermissionAuthorizationStatus

    var canProceed: Bool {
        notifications.isGranted && microphone.isGranted
    }

    func status(for step: PermissionGateStep) -> PermissionAuthorizationStatus {
        switch step {
        case .notifications:
            return notifications
        case .microphone:
            return microphone
        case .contacts:
            return contacts
        }
    }
}

struct FirstRunOnboardingState: Codable, Hashable {
    var completedVersionByOrganizationID: [String: Int]

    init(completedVersionByOrganizationID: [String: Int] = [:]) {
        self.completedVersionByOrganizationID = completedVersionByOrganizationID
    }

    func isCompleted(for organizationID: String, version: Int) -> Bool {
        (completedVersionByOrganizationID[organizationID] ?? 0) >= version
    }

    mutating func markCompleted(for organizationID: String, version: Int) {
        completedVersionByOrganizationID[organizationID] = max(
            completedVersionByOrganizationID[organizationID] ?? 0,
            version
        )
    }
}

struct DeviceContactImportCandidate: Hashable, Identifiable {
    let id: String
    let name: String?
    let phoneNumber: String
    let email: String?
}

struct DeviceContactsImportResult: Hashable {
    var created = 0
    var queued = 0
    var skipped = 0
    var failed = 0
}
