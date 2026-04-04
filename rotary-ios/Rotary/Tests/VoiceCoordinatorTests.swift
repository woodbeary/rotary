import AVFoundation
import XCTest
@testable import Rotary

final class VoiceCoordinatorTests: XCTestCase {
    func testOutboundConnectParametersUseCanonicalTwilioKeys() {
        let params = VoiceOutboundCallPlanner.connectParameters(
            orgId: "org-1",
            to: "+19495290538",
            fromLine: "+19515773701",
            contactId: "contact-1",
            displayName: "Olivia Lee"
        )

        XCTAssertEqual(
            Set(params.keys),
            Set(["To", "OrgId", "FromLine", "ContactId", "DisplayName"])
        )
        XCTAssertEqual(params["To"], "+19495290538")
        XCTAssertEqual(params["OrgId"], "org-1")
        XCTAssertEqual(params["FromLine"], "+19515773701")
        XCTAssertEqual(params["ContactId"], "contact-1")
        XCTAssertEqual(params["DisplayName"], "Olivia Lee")
        XCTAssertNil(params["toNumber"])
        XCTAssertNil(params["voicePhoneNumberId"])
        XCTAssertNil(params["contactName"])
    }

    func testOutboundConnectParametersLeaveContactIdBlankWhenMissing() {
        let params = VoiceOutboundCallPlanner.connectParameters(
            orgId: "org-1",
            to: "+19495290538",
            fromLine: "+19515773701",
            contactId: nil,
            displayName: "Olivia Lee"
        )

        XCTAssertEqual(params["ContactId"], "")
    }

    func testOutboundRoutePrefersNativeVoiceWhenTokenIsReady() {
        let tokenState = MobileVoiceTokenResponse(
            enabled: true,
            incomingEnabled: true,
            reason: nil,
            reasonCode: nil,
            incomingReason: nil,
            incomingReasonCode: nil,
            token: "twilio-token",
            identity: "device-1",
            capabilities: nil
        )

        XCTAssertEqual(
            VoiceOutboundCallPlanner.resolveRoute(
                tokenState: tokenState,
                callbackBridgeEnabled: true
            ),
            .native
        )
    }

    func testOutboundRouteFallsBackOnlyWhenCallbackBridgeIsEnabled() {
        let tokenState = MobileVoiceTokenResponse(
            enabled: false,
            incomingEnabled: false,
            reason: "Voice is not enabled for this workspace.",
            reasonCode: "voice_disabled",
            incomingReason: nil,
            incomingReasonCode: nil,
            token: nil,
            identity: nil,
            capabilities: nil
        )

        XCTAssertEqual(
            VoiceOutboundCallPlanner.resolveRoute(
                tokenState: tokenState,
                callbackBridgeEnabled: true
            ),
            .callbackBridge
        )
        XCTAssertEqual(
            VoiceOutboundCallPlanner.resolveRoute(
                tokenState: tokenState,
                callbackBridgeEnabled: false
            ),
            .unavailable("Voice is not enabled for this workspace.")
        )
    }

    func testAudioOutputMapsSpeakerAndBluetooth() {
        XCTAssertEqual(
            VoiceAudioOutput.resolve(portTypeRawValue: AVAudioSession.Port.builtInSpeaker.rawValue),
            .speaker
        )
        XCTAssertEqual(
            VoiceAudioOutput.resolve(portTypeRawValue: AVAudioSession.Port.bluetoothHFP.rawValue),
            .bluetooth
        )
    }

    func testDTMFDigitSanitizerStripsUnsupportedCharacters() {
        XCTAssertEqual(
            VoiceDTMFDigits.sanitize("1 2-3p,#x*"),
            "123#*"
        )
    }

    func testMobileCallLivePhasePrefersTransientTwilioStatus() {
        let call = makeMobileCall(
            status: "answered",
            durationSeconds: nil,
            intakePayload: [
                "last_status": .string("ringing"),
                "twilio_parent_call_sid": .string("CA_PARENT"),
                "twilio_child_call_sid": .string("CA_CHILD"),
            ]
        )

        XCTAssertEqual(call.livePhase, .ringing)
        XCTAssertEqual(call.liveStatusTitle, "Ringing")
        XCTAssertTrue(call.matchesAnyCallSID(["CA_PARENT"]))
        XCTAssertTrue(call.matchesAnyCallSID(["CA_CHILD"]))
    }

    func testMobileCallLivePhaseTreatsMachineAnswerAsVoicemail() {
        let call = makeMobileCall(
            status: "completed",
            durationSeconds: 0,
            intakePayload: [
                "last_status": .string("completed"),
                "twilio_answered_by": .string("machine_end_beep"),
            ]
        )

        XCTAssertEqual(call.livePhase, .voicemail)
        XCTAssertTrue(call.isLiveSessionTerminal)
    }

    func testMobileCallLivePhaseTreatsAnsweredCallAsConnected() {
        let call = makeMobileCall(
            status: "answered",
            durationSeconds: nil,
            intakePayload: [
                "last_status": .string("in-progress"),
            ]
        )

        XCTAssertEqual(call.livePhase, .connected)
        XCTAssertEqual(call.liveStatusTitle, "On Call")
        XCTAssertFalse(call.isLiveSessionTerminal)
    }

    private func makeMobileCall(
        status: String,
        durationSeconds: Int?,
        intakePayload: [String: JSONValue]
    ) -> MobileCall {
        MobileCall(
            id: "call-1",
            callSid: "CA_FALLBACK",
            contactId: "contact-1",
            contactName: "Olivia Lee",
            contactPhone: "+19495290538",
            lineId: "line-1",
            fromNumber: "+19515773701",
            toNumber: "+19495290538",
            status: status,
            durationSeconds: durationSeconds,
            screeningOutcome: nil,
            transferOutcome: nil,
            recordingUrl: nil,
            transcript: nil,
            summary: nil,
            agentId: nil,
            folderId: nil,
            transcriptStatus: nil,
            summarySmsSentAt: nil,
            readAt: nil,
            intakePayload: intakePayload,
            createdAt: "2026-04-02T22:00:00Z",
            updatedAt: "2026-04-02T22:00:00Z"
        )
    }
}
