import XCTest
@testable import Rotary

final class FirstRunOnboardingStateTests: XCTestCase {
    func testPermissionGateCanProceedRequiresNotificationsAndMicrophone() {
        let fullyAuthorized = PermissionGateStatus(
            notifications: .authorized,
            microphone: .authorized,
            contacts: .notDetermined
        )
        XCTAssertTrue(fullyAuthorized.canProceed)

        let notificationsDenied = PermissionGateStatus(
            notifications: .denied,
            microphone: .authorized,
            contacts: .authorized
        )
        XCTAssertFalse(notificationsDenied.canProceed)

        let microphoneDenied = PermissionGateStatus(
            notifications: .authorized,
            microphone: .denied,
            contacts: .authorized
        )
        XCTAssertFalse(microphoneDenied.canProceed)
    }

    func testPermissionGateStatusLookupMatchesStep() {
        let status = PermissionGateStatus(
            notifications: .authorized,
            microphone: .restricted,
            contacts: .denied
        )

        XCTAssertEqual(status.status(for: .notifications), .authorized)
        XCTAssertEqual(status.status(for: .microphone), .restricted)
        XCTAssertEqual(status.status(for: .contacts), .denied)
    }

    func testOnboardingVersionIsTrackedPerOrganization() {
        var state = FirstRunOnboardingState()

        XCTAssertFalse(state.isCompleted(for: "org_a", version: 1))

        state.markCompleted(for: "org_a", version: 1)
        XCTAssertTrue(state.isCompleted(for: "org_a", version: 1))
        XCTAssertFalse(state.isCompleted(for: "org_a", version: 2))

        state.markCompleted(for: "org_a", version: 3)
        XCTAssertTrue(state.isCompleted(for: "org_a", version: 2))
        XCTAssertTrue(state.isCompleted(for: "org_a", version: 3))

        state.markCompleted(for: "org_a", version: 2)
        XCTAssertTrue(state.isCompleted(for: "org_a", version: 3))

        XCTAssertFalse(state.isCompleted(for: "org_b", version: 1))
        state.markCompleted(for: "org_b", version: 1)
        XCTAssertTrue(state.isCompleted(for: "org_b", version: 1))
        XCTAssertTrue(state.isCompleted(for: "org_a", version: 3))
    }

    func testPermissionStepRequirementFlags() {
        XCTAssertTrue(PermissionGateStep.notifications.isRequired)
        XCTAssertTrue(PermissionGateStep.microphone.isRequired)
        XCTAssertFalse(PermissionGateStep.contacts.isRequired)
    }
}
