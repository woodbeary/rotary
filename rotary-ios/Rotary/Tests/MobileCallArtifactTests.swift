import XCTest
@testable import Rotary

final class MobileCallArtifactTests: XCTestCase {
    func testLiveAssistVisibilityPolicyByCallType() {
        let explicitEligible = makeCall(
            liveAssistEligible: true,
            intakePayload: [:]
        )
        XCTAssertTrue(explicitEligible.isLiveAssistEligible)
        XCTAssertTrue(explicitEligible.shouldShowLiveSteerControls)

        let explicitIneligible = makeCall(
            liveAssistEligible: false,
            intakePayload: [
                "line_owner_type": .string("agent"),
            ]
        )
        XCTAssertFalse(explicitIneligible.isLiveAssistEligible)
        XCTAssertFalse(explicitIneligible.shouldShowLiveSteerControls)

        let inferredEligible = makeCall(
            liveAssistEligible: nil,
            intakePayload: [
                "line_owner_type": .string("agent"),
            ]
        )
        XCTAssertTrue(inferredEligible.isLiveAssistEligible)
        XCTAssertTrue(inferredEligible.shouldShowLiveSteerControls)

        let joinCall = makeCall(
            liveAssistEligible: nil,
            intakePayload: [
                "line_owner_type": .string("agent"),
                "call_mode": .string("mobile_live_assist_join"),
            ]
        )
        XCTAssertFalse(joinCall.isLiveAssistEligible)
        XCTAssertFalse(joinCall.shouldShowLiveSteerControls)

        let userPlacedCall = makeCall(
            liveAssistEligible: nil,
            intakePayload: [
                "line_owner_type": .string("owner_main"),
                "line_role": .string("main"),
                "call_mode": .string("mobile_user_outbound"),
            ]
        )
        XCTAssertFalse(userPlacedCall.isLiveAssistEligible)
        XCTAssertFalse(userPlacedCall.shouldShowLiveSteerControls)
    }

    func testPlaybackRenderingStateAndLabels() {
        let voicemailPlayable = makeCall(
            recordingUrl: "https://example.com/audio.mp3",
            playbackKind: "voicemail",
            playbackStatus: "available"
        )
        XCTAssertEqual(voicemailPlayable.playbackSectionTitle, "Voicemail")
        XCTAssertTrue(voicemailPlayable.shouldShowPlaybackControl)

        let recordingProcessing = makeCall(
            recordingUrl: nil,
            playbackKind: "recording",
            playbackStatus: "processing"
        )
        XCTAssertEqual(recordingProcessing.playbackSectionTitle, "Recording")
        XCTAssertFalse(recordingProcessing.shouldShowPlaybackControl)
        XCTAssertEqual(recordingProcessing.playbackStatusMessage, "Audio is still processing.")

        let voicemailMissingAudio = makeCall(
            recordingUrl: nil,
            playbackKind: "voicemail",
            playbackStatus: "absent",
            summary: "Caller left details."
        )
        XCTAssertEqual(voicemailMissingAudio.playbackSectionTitle, "Voicemail")
        XCTAssertFalse(voicemailMissingAudio.shouldShowPlaybackControl)
        XCTAssertEqual(
            voicemailMissingAudio.playbackStatusMessage,
            "No voicemail audio is available for this call."
        )
    }

    func testVoicemailDetailRouteAndTextArtifactsDoNotRequirePlayableAudio() {
        let textOnlyVoicemail = makeCall(
            recordingUrl: nil,
            playbackKind: "voicemail",
            playbackStatus: "absent",
            transcript: "Please call me back."
        )

        XCTAssertTrue(textOnlyVoicemail.shouldLoadVoicemailDetailRoute)
        XCTAssertEqual(textOnlyVoicemail.transcriptStatusResolved, "complete")
        XCTAssertNil(textOnlyVoicemail.transcriptStatusMessage)
    }

    func testSummaryAndTranscriptStatusMessages() {
        let processing = makeCall(
            recordingUrl: nil,
            playbackKind: "recording",
            playbackStatus: "processing",
            summary: nil,
            transcript: nil
        )
        XCTAssertEqual(processing.summaryStatusMessage, "Summary is still processing.")
        XCTAssertEqual(processing.transcriptStatusMessage, "Transcript is still processing.")

        let absent = makeCall(
            recordingUrl: nil,
            playbackKind: "recording",
            playbackStatus: "absent",
            summary: nil,
            transcript: nil
        )
        XCTAssertEqual(absent.summaryStatusMessage, "Summary is not available for this call.")
        XCTAssertEqual(absent.transcriptStatusMessage, "Transcript is not available for this call.")
    }

    private func makeCall(
        recordingUrl: String? = nil,
        playbackKind: String? = nil,
        playbackStatus: String? = nil,
        summary: String? = nil,
        transcript: String? = nil,
        liveAssistEligible: Bool? = nil,
        intakePayload: [String: JSONValue] = [:]
    ) -> MobileCall {
        MobileCall(
            id: "call_1",
            callSid: "CA123",
            contactId: "contact_1",
            contactName: "Olivia Lee",
            contactPhone: "+19495290538",
            lineId: "line_1",
            fromNumber: "+19515773701",
            toNumber: "+19495290538",
            status: "missed_inbound",
            durationSeconds: 0,
            screeningOutcome: nil,
            transferOutcome: nil,
            recordingUrl: recordingUrl,
            transcript: transcript,
            summary: summary,
            agentId: nil,
            folderId: nil,
            transcriptStatus: nil,
            summarySmsSentAt: nil,
            readAt: nil,
            liveAssistEligible: liveAssistEligible,
            playbackKind: playbackKind,
            playbackStatus: playbackStatus,
            intakePayload: intakePayload,
            createdAt: "2026-04-05T18:20:00Z",
            updatedAt: "2026-04-05T18:21:00Z"
        )
    }
}
