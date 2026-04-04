import AVFoundation
import CallKit
import Foundation
import Observation
import PushKit

#if canImport(TwilioVoice)
@preconcurrency import TwilioVoice
#endif

#if DEBUG
private let rotaryDebugLastActionDefaultsKey = "rotary.debug.lastAction"
#endif

enum VoiceCoordinatorError: LocalizedError {
    case missingSession
    case missingVoiceIdentity
    case nativeVoiceUnavailable(String)
    case missingLine
    case noJoinContext

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Rotary needs an authenticated session before placing calls."
        case .missingVoiceIdentity:
            return "Rotary could not load a Twilio voice identity for this device."
        case let .nativeVoiceUnavailable(reason):
            return reason
        case .missingLine:
            return "Rotary could not find a valid phone line for this call."
        case .noJoinContext:
            return "Live assist is missing the conference context needed to join."
        }
    }
}

enum RotaryCallPresentationState: Equatable {
    case idle
    case requestingCallKit
    case startedConnecting
    case ringing
    case connected
    case ended
    case failed(String)
}

private extension RotaryCallPresentationState {
    var presentsActiveCallScreen: Bool {
        switch self {
        case .requestingCallKit, .startedConnecting, .ringing, .connected:
            return true
        case .idle, .ended, .failed:
            return false
        }
    }
}

enum VoiceAudioOutput: String, Equatable, CaseIterable {
    case receiver
    case speaker
    case bluetooth
    case headphones
    case carAudio
    case airPlay
    case unknown

    var title: String {
        switch self {
        case .receiver:
            return "Phone"
        case .speaker:
            return "Speaker"
        case .bluetooth:
            return "Bluetooth"
        case .headphones:
            return "Headphones"
        case .carAudio:
            return "Car"
        case .airPlay:
            return "AirPlay"
        case .unknown:
            return "Audio"
        }
    }

    var systemImage: String {
        switch self {
        case .receiver:
            return "phone.fill"
        case .speaker:
            return "speaker.wave.2.fill"
        case .bluetooth:
            return "dot.radiowaves.left.and.right"
        case .headphones:
            return "headphones"
        case .carAudio:
            return "car.fill"
        case .airPlay:
            return "airplayaudio"
        case .unknown:
            return "waveform"
        }
    }

    static func resolve(portTypeRawValue: String?) -> VoiceAudioOutput {
        switch portTypeRawValue {
        case AVAudioSession.Port.builtInReceiver.rawValue:
            return .receiver
        case AVAudioSession.Port.builtInSpeaker.rawValue:
            return .speaker
        case AVAudioSession.Port.bluetoothHFP.rawValue,
             AVAudioSession.Port.bluetoothLE.rawValue,
             AVAudioSession.Port.bluetoothA2DP.rawValue:
            return .bluetooth
        case AVAudioSession.Port.headphones.rawValue,
             AVAudioSession.Port.headsetMic.rawValue:
            return .headphones
        case AVAudioSession.Port.carAudio.rawValue:
            return .carAudio
        case AVAudioSession.Port.airPlay.rawValue:
            return .airPlay
        default:
            return .unknown
        }
    }
}

struct VoiceAudioRouteOption: Equatable, Identifiable {
    let output: VoiceAudioOutput
    let active: Bool

    var id: String { output.rawValue }
}

enum VoiceDTMFDigits {
    static func sanitize(_ digits: String) -> String {
        let allowed = Set("0123456789*#")
        return digits.filter { allowed.contains($0) }
    }
}

private struct RotaryPendingConnectRequest {
    let uuid: UUID
    let attemptID: UUID
    let handle: String
    let callKitHandle: String
    let callKitHandleType: CXHandle.HandleType
    let localizedCallerName: String?
    let params: [String: String]
}

private struct RotaryOutboundDialRequest {
    let phoneNumber: String
    let contactId: String?
    let fromNumber: String?
}

enum VoiceOutboundRoute: Equatable {
    case native
    case callbackBridge
    case unavailable(String)
}

private enum VoiceActiveSessionOrigin {
    case outboundDial
    case liveAssistJoin
    case incomingInvite
    case callbackBridge
}

enum VoiceOutboundCallPlanner {
    static func resolveRoute(
        tokenState: MobileVoiceTokenResponse?,
        callbackBridgeEnabled: Bool
    ) -> VoiceOutboundRoute {
        if let tokenState,
           tokenState.enabled,
           let voiceToken = tokenState.token,
           !voiceToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .native
        }

        if callbackBridgeEnabled {
            return .callbackBridge
        }

        let reason = tokenState?.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackReason = reason?.isEmpty == false ? reason! : "Rotary native calling is not ready on this device."
        return .unavailable(fallbackReason)
    }

    static func connectParameters(
        orgId: String,
        to phoneNumber: String,
        fromLine: String,
        contactId: String?,
        displayName: String
    ) -> [String: String] {
        var params: [String: String] = [
            "To": phoneNumber,
            "OrgId": orgId,
            "FromLine": fromLine,
            "ContactId": "",
            "DisplayName": displayName,
        ]

        let normalizedContactId = contactId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedContactId, !normalizedContactId.isEmpty {
            params["ContactId"] = normalizedContactId
        }

        return params
    }
}

private enum MicrophonePermissionBridge {
    static func request() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { accepted in
                continuation.resume(returning: accepted)
            }
        }
    }
}

private enum RotaryRingbackTone {
    private static let sampleRate = 8_000
    private static let bitDepth = 16
    private static let channels = 1
    private static let toneDurationSeconds = 6
    private static let activeToneSeconds = 2
    private static let firstFrequency = 440.0
    private static let secondFrequency = 480.0
    private static let amplitude = 0.28

    static func fileURL() throws -> URL {
        let directory =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent("rotary-ringback.wav")
        if !FileManager.default.fileExists(atPath: url.path) {
            try writeToneFile(to: url)
        }
        return url
    }

    private static func writeToneFile(to url: URL) throws {
        let pcmData = buildPCMData()
        var waveData = Data()
        waveData.appendASCII("RIFF")
        waveData.appendLittleEndian(UInt32(36 + pcmData.count))
        waveData.appendASCII("WAVE")
        waveData.appendASCII("fmt ")
        waveData.appendLittleEndian(UInt32(16))
        waveData.appendLittleEndian(UInt16(1))
        waveData.appendLittleEndian(UInt16(channels))
        waveData.appendLittleEndian(UInt32(sampleRate))
        let byteRate = sampleRate * channels * (bitDepth / 8)
        waveData.appendLittleEndian(UInt32(byteRate))
        let blockAlign = channels * (bitDepth / 8)
        waveData.appendLittleEndian(UInt16(blockAlign))
        waveData.appendLittleEndian(UInt16(bitDepth))
        waveData.appendASCII("data")
        waveData.appendLittleEndian(UInt32(pcmData.count))
        waveData.append(pcmData)
        try waveData.write(to: url, options: .atomic)
    }

    private static func buildPCMData() -> Data {
        let totalSamples = sampleRate * toneDurationSeconds
        var data = Data(capacity: totalSamples * MemoryLayout<Int16>.size)

        for sampleIndex in 0 ..< totalSamples {
            let time = Double(sampleIndex) / Double(sampleRate)
            let cycleTime = time.truncatingRemainder(dividingBy: Double(toneDurationSeconds))
            let sampleValue: Int16
            if cycleTime < Double(activeToneSeconds) {
                let combined =
                    sin(2 * Double.pi * firstFrequency * time) +
                    sin(2 * Double.pi * secondFrequency * time)
                let normalized = max(-1.0, min(1.0, combined * 0.5 * amplitude))
                sampleValue = Int16(normalized * Double(Int16.max))
            } else {
                sampleValue = 0
            }
            data.appendLittleEndian(sampleValue)
        }

        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}

#if DEBUG
private enum RotaryDebugVoiceEnvironment {
    static var forcesCallbackBridge: Bool {
        ProcessInfo.processInfo.environment["ROTARY_DEBUG_FORCE_CALLBACK"] == "1"
    }
}
#endif

@MainActor
@Observable
final class VoiceCoordinator: NSObject {
    static let shared = VoiceCoordinator()

    private let api: RotaryAPIClient

    var tokenState: MobileVoiceTokenResponse?
    var registrationState: DeviceRegistrationResponse?
    var lastError: String?
    var lastActionMessage: String?
    var lastJoinContext: MobileCallJoinContext?
    var activeCallUUID: UUID?
    var activeCallbackCallSid: String?
    var activeVoiceCallSid: String?
    var activeHandle: String?
    var activeRemoteAddress: String?
    var isInCall = false
    var isRegistering = false
    var isMuted = false
    var isCallOnHold = false
    var isSpeakerEnabled = false
    var currentAudioOutput: VoiceAudioOutput = .unknown
    var availableAudioRoutes: [VoiceAudioRouteOption] = []
    var lastRegistrationAt: Date?
    var callPresentationState: RotaryCallPresentationState = .idle {
        didSet {
            syncRingbackPlayback()
        }
    }
    var isCallScreenPresented = false
    var isEndingCall = false
#if DEBUG
    private var isDebugPreviewCallActive = false
#endif

    private var authToken: String?
    private var tokenProvider: RotaryTokenProvider?
    private var orgId: String?
    private var ownerLineId: String?
    private var callbackBridgeEnabled = false
    private var activeSessionOrigin: VoiceActiveSessionOrigin?
    private var activeSessionStartedAt: Date?
    private var linePhoneNumbersByID: [String: String] = [:]
    private var activeVoipPushTokenHex: String?
    private var activeVoipPushTokenData: Data?
    private var pendingConnectRequest: RotaryPendingConnectRequest?
    private var lastOutboundDialRequest: RotaryOutboundDialRequest?
    private var callbackFallbackTask: Task<Void, Never>?
    @ObservationIgnored private var outboundCallAttemptID = UUID()
    @ObservationIgnored private var ringbackPlayer: AVAudioPlayer?
    private var didConnectCurrentOutboundCall = false
    private var didAttemptCallbackFallbackCurrentOutboundCall = false
    private var audioRouteObserver: NSObjectProtocol?

#if canImport(TwilioVoice)
    private let audioDevice = DefaultAudioDevice()
    private var callKitProvider: CXProvider?
    private let callController = CXCallController()
    private var activeCallInvites: [String: CallInvite] = [:]
    private var activeCalls: [String: Call] = [:]
    private var activeCall: Call?
    private var outboundCallUUIDs: Set<String> = []
    private var userInitiatedDisconnect = false
#endif

    init(api: RotaryAPIClient? = nil) {
        self.api = api ?? RotaryAPIClient()
        super.init()

        audioRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAudioRoute()
            }
        }

#if canImport(TwilioVoice)
        TwilioVoiceSDK.audioDevice = audioDevice
        let configuration = CXProviderConfiguration(localizedName: "Rotary")
        configuration.supportsVideo = false
        configuration.supportedHandleTypes = [.generic, .phoneNumber]
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 2
        configuration.includesCallsInRecents = false

        let provider = CXProvider(configuration: configuration)
        provider.setDelegate(self, queue: nil)
        callKitProvider = provider
#endif
        refreshAudioRoute()
    }

#if DEBUG
    private func recordDebugResult(_ message: String) {
        UserDefaults.standard.set(
            "[\(ISO8601DateFormatter().string(from: Date()))] \(message)",
            forKey: rotaryDebugLastActionDefaultsKey
        )
    }
#endif

    func configureSession(
        authToken: String,
        bootstrap: MobileBootstrapReadyState,
        tokenProvider: RotaryTokenProvider? = nil
    ) async {
        self.authToken = authToken
        self.tokenProvider = tokenProvider
        orgId = bootstrap.session.orgId
        ownerLineId = bootstrap.ownerLine?.id
        callbackBridgeEnabled = bootstrap.capabilities.callbackBridgeEnabled
        linePhoneNumbersByID = Dictionary(uniqueKeysWithValues: bootstrap.lines.map { ($0.id, $0.phoneNumber) })
        RotaryLogger.trace(
            "voice configureSession org=\(bootstrap.session.orgId) ownerLinePresent=\(bootstrap.ownerLine != nil)",
            category: "voice"
        )
        await refreshVoiceState(token: authToken)
    }

    func clearSession() {
        authToken = nil
        tokenProvider = nil
        orgId = nil
        ownerLineId = nil
        callbackBridgeEnabled = false
        linePhoneNumbersByID = [:]
        tokenState = nil
        registrationState = nil
        lastJoinContext = nil
        lastActionMessage = nil
        lastError = nil
        lastRegistrationAt = nil
        callPresentationState = .idle
        lastOutboundDialRequest = nil
        resetOutboundCallAttempt()
        didConnectCurrentOutboundCall = false
        didAttemptCallbackFallbackCurrentOutboundCall = false
        activeCallbackCallSid = nil
        activeVoiceCallSid = nil
        activeRemoteAddress = nil
        isCallScreenPresented = false
        isEndingCall = false
        activeSessionOrigin = nil
        activeSessionStartedAt = nil
        resetActiveCallControls()
#if canImport(TwilioVoice)
        userInitiatedDisconnect = false
#endif
        RotaryLogger.trace("voice session cleared", category: "voice")
    }

    func refreshVoiceState(token: String) async {
        do {
            RotaryLogger.trace("voice refresh start", category: "voice")
            tokenState = try await api.voiceToken(token: token)
            lastError = nil

            guard let state = tokenState else { return }
            if state.enabled != true {
                lastError = state.reason ?? "Phone outbound app voice is not configured."
                RotaryLogger.trace("voice refresh disabled reason=\(lastError ?? "unknown")", category: "voice", level: "warning")
                return
            }

            if let voipPushTokenHex = activeVoipPushTokenHex {
                await registerCurrentDevice(token: token, voipPushToken: voipPushTokenHex)
            }
            RotaryLogger.trace(
                "voice refresh ready incoming=\(String(describing: state.incomingEnabled))",
                category: "voice"
            )
        } catch {
            lastError = error.localizedDescription
            RotaryLogger.trace("voice refresh failed: \(error.localizedDescription)", category: "voice", level: "error")
        }
    }

    func registerCurrentDevice(token: String, voipPushToken: String? = nil) async {
        isRegistering = true
        defer { isRegistering = false }

        do {
            RotaryLogger.trace("voice register device start", category: "voice")
            let effectivePushToken = voipPushToken ?? activeVoipPushTokenHex
            registrationState = try await api.registerDevice(
                token: token,
                voipPushToken: effectivePushToken,
                clientReady: true
            )
            lastRegistrationAt = Date()

#if canImport(TwilioVoice)
            if let voiceToken = tokenState?.token,
               let deviceToken = activeVoipPushTokenData {
                try await registerTwilio(accessToken: voiceToken, deviceToken: deviceToken)
            }
#endif

            lastError = nil
            lastActionMessage = "Rotary is ready for app calls on this device."
            RotaryLogger.trace("voice register device success", category: "voice")
        } catch {
            lastError = error.localizedDescription
            RotaryLogger.trace("voice register device failed: \(error.localizedDescription)", category: "voice", level: "error")
        }
    }

    func updateVoipCredentials(_ credentials: PKPushCredentials) async {
        let tokenData = credentials.token
        activeVoipPushTokenData = tokenData
        activeVoipPushTokenHex = tokenData.map { String(format: "%02x", $0) }.joined()

        guard let authToken else { return }
        await registerCurrentDevice(token: authToken, voipPushToken: activeVoipPushTokenHex)
    }

    func invalidateVoipToken() {
        activeVoipPushTokenHex = nil
        activeVoipPushTokenData = nil
    }

    func handleIncomingPush(payload: PKPushPayload, completion: (() -> Void)? = nil) {
#if canImport(TwilioVoice)
        let handled = TwilioVoiceSDK.handleNotification(
            payload.dictionaryPayload,
            delegate: self,
            delegateQueue: nil
        )
        if !handled {
            lastError = "Rotary could not process the incoming Twilio push payload."
        }
#else
        lastError = "Twilio Voice is not linked into this Rotary build yet."
#endif
        completion?()
    }

    func startOwnerCall(to phoneNumber: String, handle: String? = nil) async throws {
        guard let ownerLineId else {
            throw VoiceCoordinatorError.missingLine
        }
        try await startLineCall(
            to: phoneNumber,
            lineId: ownerLineId,
            handle: handle ?? phoneNumber
        )
    }

    func startLineCall(
        to phoneNumber: String,
        lineId: String,
        handle: String,
        contactId: String? = nil,
        contactName: String? = nil
    ) async throws {
        let authToken = try await currentAuthToken()
        let attemptID = startOutboundCallAttempt()

        let displayName = (contactName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? handle
        let fromLine = linePhoneNumbersByID[lineId]

        lastOutboundDialRequest = RotaryOutboundDialRequest(
            phoneNumber: phoneNumber,
            contactId: contactId,
            fromNumber: fromLine
        )

        activeHandle = displayName
        activeRemoteAddress = phoneNumber
        didConnectCurrentOutboundCall = false
        didAttemptCallbackFallbackCurrentOutboundCall = false
        userInitiatedDisconnect = false
        activeSessionOrigin = .outboundDial
        activeSessionStartedAt = Date()
        isCallScreenPresented = true
        isEndingCall = false

        if tokenState == nil {
            await refreshVoiceState(token: authToken)
        }

        let outboundRoute: VoiceOutboundRoute
#if DEBUG
        if RotaryDebugVoiceEnvironment.forcesCallbackBridge {
            outboundRoute = .callbackBridge
        } else {
            outboundRoute = VoiceOutboundCallPlanner.resolveRoute(
                tokenState: tokenState,
                callbackBridgeEnabled: callbackBridgeEnabled
            )
        }
#else
        outboundRoute = VoiceOutboundCallPlanner.resolveRoute(
            tokenState: tokenState,
            callbackBridgeEnabled: callbackBridgeEnabled
        )
#endif

        switch outboundRoute {
        case .callbackBridge:
            didAttemptCallbackFallbackCurrentOutboundCall = true
            try await startCallbackBridgeCall(
                attemptID: attemptID,
                token: authToken,
                phoneNumber: phoneNumber,
                lineId: lineId,
                contactId: contactId,
                displayName: displayName
            )
            return
        case let .unavailable(reason):
            throw VoiceCoordinatorError.nativeVoiceUnavailable(reason)
        case .native:
            break
        }

        guard let orgId else {
            if callbackBridgeEnabled {
                didAttemptCallbackFallbackCurrentOutboundCall = true
                try await startCallbackBridgeCall(
                    attemptID: attemptID,
                    token: authToken,
                    phoneNumber: phoneNumber,
                    lineId: lineId,
                    contactId: contactId,
                    displayName: displayName
                )
                return
            }
            throw VoiceCoordinatorError.missingVoiceIdentity
        }

        guard let fromLine, !fromLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if callbackBridgeEnabled {
                didAttemptCallbackFallbackCurrentOutboundCall = true
                try await startCallbackBridgeCall(
                    attemptID: attemptID,
                    token: authToken,
                    phoneNumber: phoneNumber,
                    lineId: lineId,
                    contactId: contactId,
                    displayName: displayName
                )
                return
            }
            throw VoiceCoordinatorError.missingLine
        }

        try await ensureMicrophoneAccess()

        RotaryLogger.trace(
            "voice startLineCall to=\(phoneNumber) lineId=\(lineId) contactId=\(contactId ?? "none")",
            category: "voice"
        )
#if DEBUG
        recordDebugResult("voice startLineCall to \(phoneNumber)")
#endif

        let uuid = UUID()
        let params = VoiceOutboundCallPlanner.connectParameters(
            orgId: orgId,
            to: phoneNumber,
            fromLine: fromLine,
            contactId: contactId,
            displayName: displayName
        )

        pendingConnectRequest = RotaryPendingConnectRequest(
            uuid: uuid,
            attemptID: attemptID,
            handle: displayName,
            callKitHandle: phoneNumber,
            callKitHandleType: .phoneNumber,
            localizedCallerName: contactName ?? displayName,
            params: params
        )
        activeCallUUID = uuid
        activeHandle = displayName
        callPresentationState = .requestingCallKit
        try await requestStartCall(
            uuid: uuid,
            handle: phoneNumber,
            handleType: .phoneNumber,
            localizedCallerName: contactName ?? displayName
        )
    }

    private func startCallbackBridgeCall(
        attemptID: UUID,
        token: String,
        phoneNumber: String,
        lineId: String,
        contactId: String?,
        displayName: String
    ) async throws {
        guard isCurrentOutboundAttempt(attemptID) else {
            RotaryLogger.trace(
                "voice callback bridge skipped because the call was canceled",
                category: "voice",
                level: "warning"
            )
            return
        }

        let fromNumber = linePhoneNumbersByID[lineId]
        RotaryLogger.trace(
            "voice startCallbackBridgeCall to=\(phoneNumber) lineId=\(lineId) contactId=\(contactId ?? "none") displayName=\(displayName)",
            category: "voice"
        )
#if DEBUG
        recordDebugResult("voice startCallbackBridgeCall to \(phoneNumber)")
#endif
        let response = try await api.startCallback(
            token: token,
            phoneNumber: phoneNumber,
            contactId: contactId,
            fromNumber: fromNumber
        )
        guard isCurrentOutboundAttempt(attemptID) else {
            RotaryLogger.trace(
                "voice callback bridge response ignored because the call was canceled",
                category: "voice",
                level: "warning"
            )
            return
        }
        activeCallUUID = UUID()
        activeCallbackCallSid = response.callSid?.trimmingCharacters(in: .whitespacesAndNewlines)
        activeVoiceCallSid = nil
        activeRemoteAddress = phoneNumber
        activeSessionOrigin = .callbackBridge
        activeSessionStartedAt = Date()
        lastOutboundDialRequest = nil
        lastError = nil
        lastActionMessage = "Rotary is calling you back to bridge this call."
        callPresentationState = .startedConnecting
        isCallScreenPresented = true
        isEndingCall = false
        RotaryLogger.trace(
            "voice callback bridge started callSid=\(response.callSid ?? "unknown") bridgeState=\(response.bridgeState ?? "unknown")",
            category: "voice"
        )
    }

    func startLiveAssistJoin(call: MobileCall, context: MobileCallJoinContext) async throws {
        guard let conferenceName = context.conferenceName, !conferenceName.isEmpty else {
            throw VoiceCoordinatorError.noJoinContext
        }

        let authToken = try await currentAuthToken()

        if tokenState == nil {
            await refreshVoiceState(token: authToken)
        }

        guard tokenState?.enabled == true, tokenState?.token != nil else {
            throw VoiceCoordinatorError.nativeVoiceUnavailable(
                tokenState?.reason ?? "Rotary native calling is not ready on this device."
            )
        }

        try await ensureMicrophoneAccess()

        let attemptID = startOutboundCallAttempt()
        let uuid = UUID()
        pendingConnectRequest = RotaryPendingConnectRequest(
            uuid: uuid,
            attemptID: attemptID,
            handle: call.contactName,
            callKitHandle: call.contactName,
            callKitHandleType: .generic,
            localizedCallerName: call.contactName,
            params: [
                "callMode": context.callMode,
                "conferenceName": conferenceName,
                "muted": context.muted ? "true" : "false",
                "listenOnly": context.muted ? "true" : "false",
                "takeOver": context.takeOver ? "true" : "false",
            ]
        )

        lastJoinContext = context
        activeCallUUID = uuid
        activeRemoteAddress = call.contactPhone ?? call.toNumber ?? call.fromNumber
        activeSessionOrigin = .liveAssistJoin
        activeSessionStartedAt = Date()
        activeHandle = call.contactName
        isMuted = context.muted
        callPresentationState = .requestingCallKit
        isCallScreenPresented = true
        isEndingCall = false
        try await requestStartCall(
            uuid: uuid,
            handle: call.contactName,
            handleType: .generic,
            localizedCallerName: call.contactName
        )
    }

    func endCurrentCall() {
        guard !isEndingCall else { return }
#if DEBUG
        if isDebugPreviewCallActive {
            endDebugPreviewCall()
            return
        }
#endif
        isEndingCall = true
        syncRingbackPlayback()
#if canImport(TwilioVoice)
        userInitiatedDisconnect = true

        if let activeCall {
            let uuid = activeCall.uuid ?? activeCallUUID
            let disconnectedCall = activeCall
            activeCalls.removeValue(forKey: uuid?.uuidString ?? "")
            outboundCallUUIDs.remove(uuid?.uuidString ?? "")
            finishOutboundCall(message: "Call ended.")
            disconnectedCall.disconnect()
            if let uuid {
                callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
                requestEndCall(uuid: uuid)
            }
            return
        }

        if let invite = activeCallInvites.values.first {
            activeCallInvites.removeValue(forKey: invite.uuid.uuidString)
            invite.reject()
            finishOutboundCall(message: "Call ended.")
            callKitProvider?.reportCall(with: invite.uuid, endedAt: Date(), reason: .remoteEnded)
            requestEndCall(uuid: invite.uuid)
            return
        }

        if let pendingConnectRequest {
            let uuid = pendingConnectRequest.uuid
            self.pendingConnectRequest = nil
            finishOutboundCall(message: "Call ended.")
            callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            requestEndCall(uuid: uuid)
            return
        }

        if activeCallbackCallSid != nil || lastOutboundDialRequest != nil {
            let callSid = activeCallbackCallSid
            let attemptID = outboundCallAttemptID
            finishOutboundCall(message: "Call ended.")
            lastError = nil
            RotaryLogger.trace(
                "voice callback cancel requested callSid=\(callSid ?? "unknown")",
                category: "voice"
            )

            Task { @MainActor [api, callSid] in
                do {
                    let sessionToken = try await currentAuthToken(forceRefresh: true)
                    _ = try await api.cancelCallback(token: sessionToken, callSid: callSid)
                    RotaryLogger.trace("voice callback cancel completed", category: "voice")
                } catch {
                    guard self.isCurrentOutboundAttempt(attemptID) else {
                        return
                    }
                    lastError = error.localizedDescription
                    RotaryLogger.trace(
                        "voice callback cancel failed: \(error.localizedDescription)",
                        category: "voice",
                        level: "error"
                    )
                }
            }
        }
#else
        lastError = "Twilio Voice is not linked into this Rotary build yet."
        callPresentationState = .failed(lastError ?? "Twilio Voice is not linked into this Rotary build yet.")
        isCallScreenPresented = false
        isEndingCall = false
#endif
    }

    func rememberJoinContext(_ context: MobileCallJoinContext) {
        lastJoinContext = context
    }

    func minimizeCallScreen() {
        isCallScreenPresented = false
    }

    func restoreCallScreen() {
        switch callPresentationState {
        case .requestingCallKit, .startedConnecting, .ringing, .connected:
            isCallScreenPresented = true
        case .idle, .ended, .failed:
            break
        }
    }

    var supportsInAppCallControls: Bool {
#if DEBUG
        if isDebugPreviewCallActive {
            return true
        }
#endif
#if canImport(TwilioVoice)
        return activeCall != nil
#else
        return false
#endif
    }

    var activeSessionTrackingKey: String {
        [
            "\(callPresentationState.presentsActiveCallScreen)",
            activeVoiceCallSid ?? "",
            activeCallbackCallSid ?? "",
            activeRemoteAddress ?? "",
            activeHandle ?? "",
        ]
        .joined(separator: "|")
    }

    func matchingObservedCall(in calls: [MobileCall]) -> MobileCall? {
        calls.first(where: matchesActiveCallRecord)
    }

    func syncObservedCallRecord(_ call: MobileCall?) {
        guard callPresentationState.presentsActiveCallScreen else { return }

        guard let call else {
            return
        }

        if call.isLiveSessionTerminal {
            finishObservedCallRecord(call)
            return
        }

        guard activeSessionOrigin == .outboundDial || activeSessionOrigin == .callbackBridge else {
            return
        }

        switch call.livePhase {
        case .calling:
            callPresentationState = .startedConnecting
            lastActionMessage = "Dialing the other side…"
        case .ringing:
            callPresentationState = .ringing
            lastActionMessage = "Ringing…"
        case .connected:
            callPresentationState = .connected
            lastActionMessage = "Call connected."
        case .voicemail, .busy, .noAnswer, .failed, .ended, .none:
            break
        }
    }

    func toggleMute() {
#if DEBUG
        if isDebugPreviewCallActive {
            isMuted.toggle()
            lastActionMessage = isMuted ? "Muted." : "Mic live."
            return
        }
#endif
#if canImport(TwilioVoice)
        guard let activeCall else {
            lastActionMessage = "Mute becomes available once Rotary is on the audio leg."
            return
        }
        activeCall.isMuted = !activeCall.isMuted
        isMuted = activeCall.isMuted
        lastActionMessage = isMuted ? "Muted." : "Mic live."
#else
        lastActionMessage = "Mute is not available in this build."
#endif
    }

    func toggleHold() {
#if DEBUG
        if isDebugPreviewCallActive {
            isCallOnHold.toggle()
            lastActionMessage = isCallOnHold ? "Call on hold." : "Call resumed."
            return
        }
#endif
#if canImport(TwilioVoice)
        guard let activeCallUUID else {
            lastActionMessage = "Hold becomes available once the call is connected."
            return
        }
        let action = CXSetHeldCallAction(call: activeCallUUID, onHold: !isCallOnHold)
        let transaction = CXTransaction(action: action)
        Task { @MainActor in
            do {
                try await request(transaction: transaction)
            } catch {
                lastError = error.localizedDescription
            }
        }
#else
        lastActionMessage = "Hold is not available in this build."
#endif
    }

    func sendDTMFDigits(_ digits: String) {
#if DEBUG
        if isDebugPreviewCallActive {
            let sanitizedDigits = VoiceDTMFDigits.sanitize(digits)
            guard !sanitizedDigits.isEmpty else { return }
            lastActionMessage = "Sent \(sanitizedDigits)"
            return
        }
#endif
#if canImport(TwilioVoice)
        let sanitizedDigits = VoiceDTMFDigits.sanitize(digits)
        guard !sanitizedDigits.isEmpty else { return }
        guard let activeCall else {
            lastActionMessage = "Keypad becomes available once Rotary is on the audio leg."
            return
        }
        activeCall.sendDigits(sanitizedDigits)
        lastActionMessage = "Sent \(sanitizedDigits)"
#else
        lastActionMessage = "Keypad is not available in this build."
#endif
    }

    func toggleSpeaker() {
#if DEBUG
        if isDebugPreviewCallActive {
            setDebugPreviewAudioOutput(isSpeakerEnabled ? .receiver : .speaker)
            return
        }
#endif
        Task { @MainActor in
            do {
                try setAudioOutput(isSpeakerEnabled ? .receiver : .speaker)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func setSpeakerEnabled(_ enabled: Bool) throws {
        try setAudioOutput(enabled ? .speaker : .receiver)
    }

    func selectAudioRoute(_ output: VoiceAudioOutput) {
#if DEBUG
        if isDebugPreviewCallActive {
            setDebugPreviewAudioOutput(output)
            return
        }
#endif
        Task { @MainActor in
            do {
                try setAudioOutput(output)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func setAudioOutput(_ output: VoiceAudioOutput) throws {
        let audioSession = AVAudioSession.sharedInstance()
        switch output {
        case .speaker:
            try audioSession.setPreferredInput(nil)
            try audioSession.overrideOutputAudioPort(.speaker)
        case .receiver:
            try audioSession.overrideOutputAudioPort(.none)
            try audioSession.setPreferredInput(preferredInput(for: .receiver))
        case .bluetooth, .headphones, .carAudio, .airPlay:
            try audioSession.overrideOutputAudioPort(.none)
            if let input = preferredInput(for: output) {
                try audioSession.setPreferredInput(input)
            }
        case .unknown:
            try audioSession.overrideOutputAudioPort(.none)
            try audioSession.setPreferredInput(nil)
        }
        refreshAudioRoute()
    }

    func refreshAudioRoute() {
#if DEBUG
        if isDebugPreviewCallActive {
            availableAudioRoutes = debugPreviewRoutes(active: currentAudioOutput)
            isSpeakerEnabled = currentAudioOutput == .speaker
            return
        }
#endif
        let audioSession = AVAudioSession.sharedInstance()
        let outputPortType = audioSession.currentRoute.outputs.first?.portType.rawValue
        currentAudioOutput = VoiceAudioOutput.resolve(portTypeRawValue: outputPortType)
        isSpeakerEnabled = currentAudioOutput == .speaker

        var resolvedRoutes: [VoiceAudioOutput] = []
        if currentAudioOutput != .unknown {
            resolvedRoutes.append(currentAudioOutput)
        }
        resolvedRoutes.append(contentsOf: audioSession.availableInputs?.compactMap { input in
            switch VoiceAudioOutput.resolve(portTypeRawValue: input.portType.rawValue) {
            case .speaker, .unknown:
                return nil
            case let output:
                return output
            }
        } ?? [])
        resolvedRoutes.append(.speaker)
        if !resolvedRoutes.contains(.receiver) {
            resolvedRoutes.append(.receiver)
        }

        var seen = Set<String>()
        availableAudioRoutes = resolvedRoutes.compactMap { output in
            guard seen.insert(output.rawValue).inserted else { return nil }
            return VoiceAudioRouteOption(output: output, active: output == currentAudioOutput)
        }
    }

    private func syncActiveCallState(from call: Call?) {
#if canImport(TwilioVoice)
        guard let call else {
            activeVoiceCallSid = nil
            resetActiveCallControls()
            return
        }
        activeVoiceCallSid = call.sid.trimmingCharacters(in: .whitespacesAndNewlines)
        isMuted = call.isMuted
        isCallOnHold = call.isOnHold
#else
        _ = call
#endif
        refreshAudioRoute()
    }

    private func resetActiveCallControls() {
        isMuted = false
        isCallOnHold = false
        isSpeakerEnabled = false
        currentAudioOutput = .unknown
        availableAudioRoutes = []
        stopRingbackPlayback()
#if DEBUG
        isDebugPreviewCallActive = false
#endif
    }

    @discardableResult
    private func startOutboundCallAttempt() -> UUID {
        let attemptID = UUID()
        outboundCallAttemptID = attemptID
        return attemptID
    }

    private func resetOutboundCallAttempt() {
        outboundCallAttemptID = UUID()
        callbackFallbackTask?.cancel()
        callbackFallbackTask = nil
    }

    private func finishOutboundCall(message: String) {
        pendingConnectRequest = nil
        activeCall = nil
        activeCallbackCallSid = nil
        activeCallUUID = nil
        activeVoiceCallSid = nil
        activeHandle = nil
        activeRemoteAddress = nil
        lastOutboundDialRequest = nil
        isInCall = false
        activeSessionOrigin = nil
        activeSessionStartedAt = nil
        resetActiveCallControls()
        resetOutboundCallAttempt()
        didAttemptCallbackFallbackCurrentOutboundCall = false
        callPresentationState = .ended
        isCallScreenPresented = false
        isEndingCall = false
        lastActionMessage = message
    }

    private func isCurrentOutboundAttempt(_ attemptID: UUID) -> Bool {
        outboundCallAttemptID == attemptID
    }

    private func matchesActiveCallRecord(_ call: MobileCall) -> Bool {
        if call.matchesAnyCallSID([activeVoiceCallSid, activeCallbackCallSid]) {
            return true
        }

        guard let activeSessionStartedAt else {
            return false
        }

        if call.matchesPhoneNumber(activeRemoteAddress),
           call.wasCreated(near: activeSessionStartedAt) {
            return true
        }

        return false
    }

    private var shouldPlayRingback: Bool {
        guard !isEndingCall else { return false }
        guard activeSessionOrigin == .outboundDial else { return false }
        switch callPresentationState {
        case .startedConnecting, .ringing:
            return true
        case .requestingCallKit, .connected, .ended, .idle, .failed:
            return false
        }
    }

    private func syncRingbackPlayback() {
        if shouldPlayRingback {
            startRingbackPlaybackIfNeeded()
        } else {
            stopRingbackPlayback()
        }
    }

    private func startRingbackPlaybackIfNeeded() {
        if let ringbackPlayer {
            if !ringbackPlayer.isPlaying {
                ringbackPlayer.currentTime = 0
                ringbackPlayer.play()
            }
            return
        }

        do {
            let url = try RotaryRingbackTone.fileURL()
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.72
            player.prepareToPlay()
            player.play()
            ringbackPlayer = player
            RotaryLogger.trace("voice ringback started", category: "voice")
        } catch {
            RotaryLogger.trace(
                "voice ringback failed: \(error.localizedDescription)",
                category: "voice",
                level: "error"
            )
        }
    }

    private func stopRingbackPlayback() {
        if ringbackPlayer != nil {
            RotaryLogger.trace("voice ringback stopped", category: "voice")
        }
        ringbackPlayer?.stop()
        ringbackPlayer = nil
    }

    private func finishObservedCallRecord(_ call: MobileCall) {
        let message = observedTerminalMessage(for: call)

#if canImport(TwilioVoice)
        if let activeCall {
            let uuid = activeCall.uuid ?? activeCallUUID
            let disconnectedCall = activeCall
            activeCalls.removeValue(forKey: uuid?.uuidString ?? "")
            outboundCallUUIDs.remove(uuid?.uuidString ?? "")
            self.activeCall = nil
            activeCallUUID = nil
            activeVoiceCallSid = nil
            activeHandle = nil
            activeRemoteAddress = nil
            isInCall = false
            lastOutboundDialRequest = nil
            activeSessionOrigin = nil
            activeSessionStartedAt = nil
            resetActiveCallControls()
            callPresentationState = .ended
            isCallScreenPresented = false
            isEndingCall = false
            lastActionMessage = message
            userInitiatedDisconnect = true
            disconnectedCall.disconnect()
            if let uuid {
                callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
                requestEndCall(uuid: uuid)
            }
            return
        }
#endif

        if activeCallbackCallSid != nil || lastOutboundDialRequest != nil {
            activeCallbackCallSid = nil
            activeCallUUID = nil
            activeVoiceCallSid = nil
            activeHandle = nil
            activeRemoteAddress = nil
            lastOutboundDialRequest = nil
            isInCall = false
            activeSessionOrigin = nil
            activeSessionStartedAt = nil
            resetActiveCallControls()
            callPresentationState = .ended
            isCallScreenPresented = false
            isEndingCall = false
            lastActionMessage = message
        }
    }

    private func observedTerminalMessage(for call: MobileCall) -> String {
        switch call.livePhase {
        case .voicemail:
            return "Reached voicemail."
        case .busy:
            return "Line busy."
        case .noAnswer:
            return "No answer."
        case .failed:
            return "Call failed."
        case .ended, .calling, .ringing, .connected, .none:
            return "Call ended."
        }
    }

#if DEBUG
    func showDebugPreviewCall(handle: String = "Rotary Preview Call") {
        isDebugPreviewCallActive = true
        activeCallUUID = UUID()
        activeHandle = handle
        isInCall = true
        isEndingCall = false
        isMuted = false
        isCallOnHold = false
        currentAudioOutput = .receiver
        availableAudioRoutes = debugPreviewRoutes(active: .receiver)
        isSpeakerEnabled = false
        lastActionMessage = "Debug preview call"
        callPresentationState = .connected
        isCallScreenPresented = true
        recordDebugResult("debug preview call presented")
    }

    private func endDebugPreviewCall() {
        lastActionMessage = "Ending call..."
        activeCallUUID = nil
        activeHandle = nil
        isInCall = false
        callPresentationState = .ended
        isCallScreenPresented = false
        isEndingCall = false
        resetActiveCallControls()
        recordDebugResult("debug preview call ended")
    }

    private func setDebugPreviewAudioOutput(_ output: VoiceAudioOutput) {
        currentAudioOutput = output
        isSpeakerEnabled = output == .speaker
        availableAudioRoutes = debugPreviewRoutes(active: output)
    }

    private func debugPreviewRoutes(active output: VoiceAudioOutput) -> [VoiceAudioRouteOption] {
        let routes: [VoiceAudioOutput] = [.receiver, .speaker, .bluetooth]
        return routes.map { route in
            VoiceAudioRouteOption(output: route, active: route == output)
        }
    }
#endif

    private func preferredInput(for output: VoiceAudioOutput) -> AVAudioSessionPortDescription? {
        let availableInputs = AVAudioSession.sharedInstance().availableInputs ?? []

        switch output {
        case .receiver:
            return availableInputs.first { $0.portType == .builtInMic }
        case .bluetooth:
            return availableInputs.first {
                $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE || $0.portType == .bluetoothA2DP
            }
        case .headphones:
            return availableInputs.first {
                $0.portType == .headphones || $0.portType == .headsetMic
            }
        case .carAudio:
            return availableInputs.first { $0.portType == .carAudio }
        case .airPlay:
            return availableInputs.first { $0.portType == .airPlay }
        case .speaker, .unknown:
            return nil
        }
    }

    private func requestStartCall(
        uuid: UUID,
        handle: String,
        handleType: CXHandle.HandleType,
        localizedCallerName: String?
    ) async throws {
#if canImport(TwilioVoice)
        let callHandle = CXHandle(type: handleType, value: handle)
        let action = CXStartCallAction(call: uuid, handle: callHandle)
        action.isVideo = false
        let transaction = CXTransaction(action: action)

        try await request(transaction: transaction)
        callPresentationState = .startedConnecting

        let update = CXCallUpdate()
        update.remoteHandle = callHandle
        update.supportsDTMF = true
        update.supportsHolding = true
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.hasVideo = false
        if let localizedCallerName, !localizedCallerName.isEmpty {
            update.localizedCallerName = localizedCallerName
        }
        callKitProvider?.reportCall(with: uuid, updated: update)
#else
        callPresentationState = .failed("Twilio Voice is not linked into this Rotary build yet.")
        throw VoiceCoordinatorError.nativeVoiceUnavailable(
            "Twilio Voice is not linked into this Rotary build yet."
        )
#endif
    }

    private func requestEndCall(uuid: UUID?) {
#if canImport(TwilioVoice)
        guard let uuid else { return }
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        Task { @MainActor in
            do {
                try await request(transaction: transaction)
            } catch {
                lastError = error.localizedDescription
            }
        }
#else
        _ = uuid
#endif
    }

    private func request(transaction: CXTransaction) async throws {
#if canImport(TwilioVoice)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            callController.request(transaction) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
#else
        _ = transaction
        throw VoiceCoordinatorError.nativeVoiceUnavailable(
            "Twilio Voice is not linked into this Rotary build yet."
        )
#endif
    }

    private func ensureMicrophoneAccess() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            return
        case .denied:
            throw VoiceCoordinatorError.nativeVoiceUnavailable(
                "Microphone access is off for Rotary. Enable it in Settings to place app calls."
            )
        case .undetermined:
            let granted = await MicrophonePermissionBridge.request()
            guard granted else {
                throw VoiceCoordinatorError.nativeVoiceUnavailable(
                    "Microphone access is required to place app calls."
                )
            }
        @unknown default:
            throw VoiceCoordinatorError.nativeVoiceUnavailable(
                "Rotary could not confirm microphone access for this call."
            )
        }
    }

    private func currentAuthToken(forceRefresh: Bool = false) async throws -> String {
        if let tokenProvider {
            let token = try await tokenProvider(forceRefresh)
            authToken = token
            return token
        }

        guard let authToken else {
            throw VoiceCoordinatorError.missingSession
        }
        return authToken
    }
}

#if canImport(TwilioVoice)
extension VoiceCoordinator: @preconcurrency NotificationDelegate {
    func callInviteReceived(callInvite: CallInvite) {
        activeCallInvites[callInvite.uuid.uuidString] = callInvite
        activeHandle = (callInvite.from ?? "Rotary caller").replacingOccurrences(of: "client:", with: "")
        activeRemoteAddress = callInvite.from?.replacingOccurrences(of: "client:", with: "")
        activeSessionOrigin = .incomingInvite
        activeSessionStartedAt = Date()
        callPresentationState = .ringing
        isCallScreenPresented = true
        isEndingCall = false
        lastActionMessage = "Incoming Rotary call ready."

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: activeHandle ?? "Rotary caller")
        update.supportsDTMF = true
        update.supportsHolding = true
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.hasVideo = false

        callKitProvider?.reportNewIncomingCall(with: callInvite.uuid, update: update) { [weak self] error in
            if let error {
                let message = error.localizedDescription
                DispatchQueue.main.async {
                    self?.lastError = message
                }
            }
        }
    }

    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        let matchingInvite = activeCallInvites.values.first { $0.callSid == cancelledCallInvite.callSid }
        if let invite = matchingInvite {
            activeCallInvites.removeValue(forKey: invite.uuid.uuidString)
            callKitProvider?.reportCall(with: invite.uuid, endedAt: Date(), reason: .remoteEnded)
        }
        if !error.localizedDescription.isEmpty {
            lastError = error.localizedDescription
        }
    }
}

extension VoiceCoordinator: @preconcurrency CallDelegate {
    private func isTrackedCall(_ call: Call) -> Bool {
        guard let uuidString = call.uuid?.uuidString else {
            return false
        }
        return activeCalls[uuidString] != nil
    }

    func callDidStartRinging(call: Call) {
        guard isTrackedCall(call) else {
            RotaryLogger.trace("voice ignoring stale ringing callback", category: "voice", level: "warning")
            return
        }
        activeCall = call
        activeCallUUID = call.uuid
        activeHandle = activeHandle ?? call.from
        activeRemoteAddress = activeRemoteAddress ?? call.from
        syncActiveCallState(from: call)
        if activeSessionOrigin == .outboundDial {
            callPresentationState = .ringing
            lastActionMessage = "Ringing…"
        } else {
            callPresentationState = .ringing
            lastActionMessage = "Calling \(activeHandle ?? "Rotary contact")…"
        }
        isCallScreenPresented = true
        isEndingCall = false
#if DEBUG
        recordDebugResult("voice callDidStartRinging \(activeHandle ?? call.from ?? "unknown")")
#endif
    }

    func callDidConnect(call: Call) {
        guard isTrackedCall(call) else {
            RotaryLogger.trace("voice ignoring stale connect callback", category: "voice", level: "warning")
            return
        }
        activeCall = call
        activeCallUUID = call.uuid
        isInCall = true
        didConnectCurrentOutboundCall = true
        syncActiveCallState(from: call)
        callPresentationState = .connected
        lastActionMessage = "Call connected."
        isCallScreenPresented = true
        isEndingCall = false
        lastError = nil
        lastOutboundDialRequest = nil
#if DEBUG
        recordDebugResult("voice callDidConnect")
#endif

        if let uuid = call.uuid, outboundCallUUIDs.contains(uuid.uuidString) {
            callKitProvider?.reportOutgoingCall(with: uuid, connectedAt: Date())
        }
    }

    func callIsReconnecting(call: Call, error: Error) {
        guard isTrackedCall(call) else {
            RotaryLogger.trace("voice ignoring stale reconnecting callback", category: "voice", level: "warning")
            return
        }
        activeCall = call
        activeCallUUID = call.uuid
        isInCall = true
        syncActiveCallState(from: call)
        lastError = error.localizedDescription
        lastActionMessage = "Reconnecting…"
    }

    func callDidReconnect(call: Call) {
        guard isTrackedCall(call) else {
            RotaryLogger.trace("voice ignoring stale reconnect callback", category: "voice", level: "warning")
            return
        }
        activeCall = call
        activeCallUUID = call.uuid
        isInCall = true
        syncActiveCallState(from: call)
        lastError = nil
        lastActionMessage = "Call reconnected."
    }

    func callDidFailToConnect(call: Call, error: Error) {
        guard isTrackedCall(call) else {
            RotaryLogger.trace("voice ignoring stale connect failure callback", category: "voice", level: "warning")
            return
        }
        let wasUserInitiatedDisconnect = userInitiatedDisconnect
        if let uuid = call.uuid {
            callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            outboundCallUUIDs.remove(uuid.uuidString)
        }
        activeCalls.removeValue(forKey: call.uuid?.uuidString ?? "")
        if activeCall?.uuid == call.uuid {
            activeCall = nil
        }
        activeCallUUID = nil
        activeVoiceCallSid = nil
        isInCall = false
        didConnectCurrentOutboundCall = false
        resetActiveCallControls()
        if wasUserInitiatedDisconnect || isEndingCall {
            lastError = nil
            finishOutboundCall(message: "Call ended.")
        } else if beginCallbackFallbackIfPossible(for: error.localizedDescription) {
            lastError = nil
            lastActionMessage = "Switching this call to Rotary callback…"
            callPresentationState = .startedConnecting
            isCallScreenPresented = true
            isEndingCall = false
        } else {
            lastError = error.localizedDescription
            callPresentationState = .failed(error.localizedDescription)
            isCallScreenPresented = false
            isEndingCall = false
            activeRemoteAddress = nil
            activeSessionOrigin = nil
            activeSessionStartedAt = nil
        }
        userInitiatedDisconnect = false
#if DEBUG
        recordDebugResult("voice callDidFailToConnect \(error.localizedDescription)")
#endif
    }

    func callDidDisconnect(call: Call, error: Error?) {
        guard isTrackedCall(call) else {
            RotaryLogger.trace("voice ignoring stale disconnect callback", category: "voice", level: "warning")
            return
        }
        let wasUserInitiatedDisconnect = userInitiatedDisconnect
        let wasConnected = didConnectCurrentOutboundCall
        let uuid = call.uuid
        activeCalls.removeValue(forKey: uuid?.uuidString ?? "")
        outboundCallUUIDs.remove(uuid?.uuidString ?? "")
        if activeCall?.uuid == uuid {
            activeCall = nil
        }
        activeCallUUID = nil
        activeVoiceCallSid = nil
        isInCall = false
        didConnectCurrentOutboundCall = false
        resetActiveCallControls()

        if !wasUserInitiatedDisconnect, let uuid {
            callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: error == nil ? .remoteEnded : .failed)
        }
        userInitiatedDisconnect = false

        if wasUserInitiatedDisconnect || isEndingCall {
            lastError = nil
            finishOutboundCall(message: "Call ended.")
            _ = call
            return
        }

        if let error {
            if !wasConnected, beginCallbackFallbackIfPossible(for: error.localizedDescription) {
                lastError = nil
                lastActionMessage = "Switching this call to Rotary callback…"
                callPresentationState = .startedConnecting
                isCallScreenPresented = true
                isEndingCall = false
            } else {
                lastError = error.localizedDescription
                callPresentationState = .failed(error.localizedDescription)
                isCallScreenPresented = false
                isEndingCall = false
                activeRemoteAddress = nil
                activeSessionOrigin = nil
                activeSessionStartedAt = nil
            }
#if DEBUG
            recordDebugResult("voice callDidDisconnect \(error.localizedDescription)")
#endif
        } else {
            finishOutboundCall(message: "Call ended.")
#if DEBUG
            recordDebugResult("voice callDidDisconnect")
#endif
        }
    }
}

extension VoiceCoordinator: @preconcurrency CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        audioDevice.isEnabled = false
        activeCallInvites.removeAll()
        activeCalls.removeAll()
        activeCall = nil
        activeCallUUID = nil
        activeCallbackCallSid = nil
        activeVoiceCallSid = nil
        activeRemoteAddress = nil
        activeHandle = nil
        pendingConnectRequest = nil
        lastOutboundDialRequest = nil
        resetOutboundCallAttempt()
        didAttemptCallbackFallbackCurrentOutboundCall = false
        isInCall = false
        didConnectCurrentOutboundCall = false
        activeSessionOrigin = nil
        activeSessionStartedAt = nil
        resetActiveCallControls()
        callPresentationState = .idle
        isCallScreenPresented = false
        isEndingCall = false
        userInitiatedDisconnect = false
        _ = provider
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = true
        _ = provider
        _ = audioSession
        refreshAudioRoute()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = false
        _ = provider
        _ = audioSession
        resetActiveCallControls()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        if connectPendingRequest(uuid: action.callUUID) {
            provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let invite = activeCallInvites[action.callUUID.uuidString] else {
            action.fail()
            return
        }

        let acceptOptions = AcceptOptions(callInvite: invite) { builder in
            builder.uuid = invite.uuid
        }
        let call = invite.accept(options: acceptOptions, delegate: self)
        activeCallInvites.removeValue(forKey: action.callUUID.uuidString)
        activeCalls[action.callUUID.uuidString] = call
        activeCall = call
        activeCallUUID = call.uuid
        isInCall = true
        activeSessionOrigin = .incomingInvite
        activeSessionStartedAt = Date()
        syncActiveCallState(from: call)
        callPresentationState = .connected
        isCallScreenPresented = true
        isEndingCall = false
        action.fulfill()
        _ = provider
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        userInitiatedDisconnect = true
        if let invite = activeCallInvites[action.callUUID.uuidString] {
            invite.reject()
            activeCallInvites.removeValue(forKey: action.callUUID.uuidString)
            finishOutboundCall(message: "Call ended.")
            action.fulfill()
            _ = provider
            return
        } else if let call = activeCalls[action.callUUID.uuidString] {
            call.disconnect()
            activeCalls.removeValue(forKey: action.callUUID.uuidString)
            finishOutboundCall(message: "Call ended.")
            action.fulfill()
            _ = provider
            return
        } else if pendingConnectRequest?.uuid == action.callUUID {
            pendingConnectRequest = nil
            finishOutboundCall(message: "Call ended.")
            action.fulfill()
            _ = provider
            return
        } else if activeCallbackCallSid != nil || lastOutboundDialRequest != nil {
            let callSid = activeCallbackCallSid
            let attemptID = outboundCallAttemptID
            finishOutboundCall(message: "Call ended.")
            RotaryLogger.trace(
                "voice callback cancel requested callSid=\(callSid ?? "unknown")",
                category: "voice"
            )

            Task { @MainActor [api, callSid] in
                do {
                    let sessionToken = try await currentAuthToken(forceRefresh: true)
                    _ = try await api.cancelCallback(token: sessionToken, callSid: callSid)
                    RotaryLogger.trace("voice callback cancel completed", category: "voice")
                } catch {
                    guard self.isCurrentOutboundAttempt(attemptID) else {
                        return
                    }
                    lastError = error.localizedDescription
                    RotaryLogger.trace(
                        "voice callback cancel failed: \(error.localizedDescription)",
                        category: "voice",
                        level: "error"
                    )
                }
            }

            action.fulfill()
            _ = provider
            return
        }

        finishOutboundCall(message: "Call ended.")
        action.fulfill()
        _ = provider
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let call = activeCalls[action.callUUID.uuidString] else {
            action.fail()
            return
        }

        call.isOnHold = action.isOnHold
        if !call.isOnHold {
            audioDevice.isEnabled = true
            activeCall = call
        }
        syncActiveCallState(from: call)
        action.fulfill()
        _ = provider
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        guard let call = activeCalls[action.callUUID.uuidString] else {
            action.fail()
            return
        }

        call.sendDigits(action.digits)
        action.fulfill()
        _ = provider
    }

    private func connectPendingRequest(uuid: UUID) -> Bool {
        guard let pendingConnectRequest else {
            RotaryLogger.trace(
                "voice connectPendingRequest ignored because the call was already canceled",
                category: "voice",
                level: "warning"
            )
            return false
        }

        guard pendingConnectRequest.uuid == uuid else {
            RotaryLogger.trace(
                "voice connectPendingRequest ignored mismatched uuid=\(uuid.uuidString)",
                category: "voice",
                level: "warning"
            )
            return false
        }

        guard isCurrentOutboundAttempt(pendingConnectRequest.attemptID) else {
            RotaryLogger.trace(
                "voice connectPendingRequest ignored stale outbound attempt",
                category: "voice",
                level: "warning"
            )
            return false
        }

        guard let accessToken = tokenState?.token,
              !accessToken.isEmpty else {
            lastError = VoiceCoordinatorError.missingVoiceIdentity.localizedDescription
            callPresentationState = .failed(lastError ?? "Rotary could not load a Twilio voice identity for this device.")
            isCallScreenPresented = false
            isEndingCall = false
            return false
        }

        let options = ConnectOptions(accessToken: accessToken) { builder in
            builder.params = pendingConnectRequest.params
            builder.uuid = uuid
        }

        let call = TwilioVoiceSDK.connect(options: options, delegate: self)
        outboundCallUUIDs.insert(uuid.uuidString)
        activeCalls[uuid.uuidString] = call
        activeCall = call
        activeCallUUID = uuid
        activeHandle = pendingConnectRequest.handle
        syncActiveCallState(from: call)
        callPresentationState = .startedConnecting
        isCallScreenPresented = true
        isEndingCall = false
        lastActionMessage = "Starting \(pendingConnectRequest.handle)…"
#if DEBUG
        recordDebugResult("voice connectPendingRequest for \(pendingConnectRequest.handle)")
#endif
        self.pendingConnectRequest = nil
        return true
    }

    private func registerTwilio(accessToken: String, deviceToken: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: deviceToken) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    @discardableResult
    private func beginCallbackFallbackIfPossible(for errorText: String) -> Bool {
        guard callbackBridgeEnabled else {
            if !errorText.isEmpty {
                RotaryLogger.trace(
                    "voice callback fallback skipped because capability is disabled reason=\(errorText)",
                    category: "voice",
                    level: "warning"
                )
            }
            return false
        }
        guard !isEndingCall,
              !didAttemptCallbackFallbackCurrentOutboundCall,
              callbackFallbackTask == nil,
              let request = lastOutboundDialRequest else {
            return false
        }

        let attemptID = outboundCallAttemptID
        didAttemptCallbackFallbackCurrentOutboundCall = true
        callbackFallbackTask = Task { @MainActor [api, attemptID, request] in
            defer { callbackFallbackTask = nil }

            do {
                try Task.checkCancellation()
                guard self.isCurrentOutboundAttempt(attemptID), !self.isEndingCall else {
                    return
                }
                if errorText.isEmpty {
                    RotaryLogger.trace(
                        "voice callback fallback after native connect failure",
                        category: "voice",
                        level: "warning"
                    )
                } else {
                    RotaryLogger.trace(
                        "voice callback fallback after native connect failure reason=\(errorText)",
                        category: "voice",
                        level: "warning"
                    )
                }
                let sessionToken = try await currentAuthToken(forceRefresh: true)
                try Task.checkCancellation()
                guard self.isCurrentOutboundAttempt(attemptID), !self.isEndingCall else {
                    return
                }
                let response = try await api.startCallback(
                    token: sessionToken,
                    phoneNumber: request.phoneNumber,
                    contactId: request.contactId,
                    fromNumber: request.fromNumber
                )
                try Task.checkCancellation()
                guard self.isCurrentOutboundAttempt(attemptID), !self.isEndingCall else {
                    return
                }
                activeCallbackCallSid =
                    response.callSid?.trimmingCharacters(in: .whitespacesAndNewlines)
                activeVoiceCallSid = nil
                activeSessionOrigin = .callbackBridge
                activeSessionStartedAt = Date()
                lastActionMessage = "Rotary is calling you back to bridge this call."
                lastError = nil
                callPresentationState = .startedConnecting
                isCallScreenPresented = true
                isEndingCall = false
                lastOutboundDialRequest = nil
                RotaryLogger.trace(
                    "voice callback fallback started callSid=\(response.callSid ?? "unknown")",
                    category: "voice"
                )
            } catch is CancellationError {
                RotaryLogger.trace("voice callback fallback cancelled", category: "voice")
            } catch {
                lastError = error.localizedDescription
                callPresentationState = .failed(error.localizedDescription)
                isCallScreenPresented = false
                isEndingCall = false
            }
        }
        return true
    }
}
#endif
