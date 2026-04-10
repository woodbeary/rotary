import XCTest
@testable import Rotary

final class RotaryAPIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    @MainActor
    func testVoiceTokenUsesConfiguredIOSPushEnvironment() {
        let config = AppConfig(
            apiBaseURL: URL(string: "https://example.com")!,
            authBaseURL: URL(string: "https://example.com")!,
            hostedSignInURLOverride: nil,
            iosPushEnvironment: "development",
            clerkPublishableKey: nil,
            clerkFrontendAPI: "clerk.example.com",
            sentryDSN: nil,
            appVersion: "1.0",
            buildNumber: "1"
        )

        let client = RotaryAPIClient(config: config)
        XCTAssertEqual(client.resolveIOSPushEnvironment(), "development")
    }

    @MainActor
    func testCallbackCancelPathAppendsQueryEncodedCallSid() {
        let config = AppConfig(
            apiBaseURL: URL(string: "https://example.com")!,
            authBaseURL: URL(string: "https://example.com")!,
            hostedSignInURLOverride: nil,
            iosPushEnvironment: "development",
            clerkPublishableKey: nil,
            clerkFrontendAPI: "clerk.example.com",
            sentryDSN: nil,
            appVersion: "1.0",
            buildNumber: "1"
        )

        let client = RotaryAPIClient(config: config)
        XCTAssertEqual(client.callbackCancelPath(callSid: "CA123"), "/api/mobile/calls/callback?callSid=CA123")

        let encodedPath = client.callbackCancelPath(callSid: "  CA 123?# ")
        let components = URLComponents(string: encodedPath)
        XCTAssertEqual(components?.path, "/api/mobile/calls/callback")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "callSid" })?.value, "CA 123?#")
    }

    @MainActor
    func testCancelCallbackWithoutCallSidUsesBaseDeleteRoute() async throws {
        let config = AppConfig(
            apiBaseURL: URL(string: "https://example.com")!,
            authBaseURL: URL(string: "https://example.com")!,
            hostedSignInURLOverride: nil,
            iosPushEnvironment: "development",
            clerkPublishableKey: nil,
            clerkFrontendAPI: "clerk.example.com",
            sentryDSN: nil,
            appVersion: "1.0",
            buildNumber: "1"
        )

        let session = URLSession(configuration: makeURLSessionConfiguration())
        let client = RotaryAPIClient(config: config, session: session)

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, "/api/mobile/calls/callback")
            XCTAssertEqual(components.queryItems ?? [], [])
            XCTAssertEqual(request.httpMethod, "DELETE")

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let responseBody = #"""
            {
              "success": true,
              "callSid": null,
              "bridgeState": "idle"
            }
            """#.data(using: .utf8)!
            return (response, responseBody)
        }

        let response = try await client.cancelCallback(token: "session-token", callSid: nil)
        XCTAssertEqual(response.success, true)
        XCTAssertNil(response.callSid)
        XCTAssertEqual(response.bridgeState, "idle")
    }

    @MainActor
    func testConversationPreviewSanitizerStripsMarkdownAndSignoffArtifacts() {
        let preview = """
        ### Short Action Plan
        - Call the venue
        - Confirm interpreter availability
        [signoff:signoff-1775676669368]
        """

        XCTAssertEqual(
            rotarySanitizedConversationPreview(preview),
            "Short Action Plan Call the venue Confirm interpreter availability"
        )
    }

    @MainActor
    func testConversationTextSanitizerPreservesParagraphBreaks() {
        let body = """
        ### Update

        First paragraph with **bold** text.


        - Second paragraph item
        [signoff:signoff-1]
        """

        XCTAssertEqual(
            rotarySanitizedConversationText(body),
            "Update\n\nFirst paragraph with bold text.\nSecond paragraph item"
        )
    }

    @MainActor
    func testVoicePresetEligibilityRequiresExplicitV3AndExpressiveMetadata() {
        let eligible = MobileVoicePreset(
            id: "voice-1",
            name: "Conversational",
            provider: "elevenlabs",
            category: "agent",
            description: "Realtime voice",
            previewUrl: nil,
            labels: ["use_case": "conversational"],
            ttsModelFamily: "v3-conversational",
            expressiveModeSupported: true,
            realtimeSupported: true
        )

        let ineligible = MobileVoicePreset(
            id: "voice-2",
            name: "Legacy",
            provider: "elevenlabs",
            category: "agent",
            description: "Legacy voice",
            previewUrl: nil,
            labels: nil,
            ttsModelFamily: "v3",
            expressiveModeSupported: true,
            realtimeSupported: true
        )

        XCTAssertTrue(eligible.rotaryV3ExpressiveEligible)
        XCTAssertFalse(ineligible.rotaryV3ExpressiveEligible)
    }

    @MainActor
    func testVoicePresetEligibilityUsesMetadataLabelsWhenTopLevelFieldsAreAbsent() {
        let eligible = MobileVoicePreset(
            id: "voice-3",
            name: "Agent Voice",
            provider: "elevenlabs",
            category: "agent",
            description: nil,
            previewUrl: nil,
            labels: [
                "tts_model_family": "v3-conversational",
                "supports_expressive_mode": "true",
                "supports_realtime": "true",
            ],
            ttsModelFamily: nil,
            expressiveModeSupported: nil,
            realtimeSupported: nil
        )

        XCTAssertTrue(eligible.rotaryV3ExpressiveEligible)
        XCTAssertGreaterThanOrEqual(eligible.rotaryRealtimePriority, 2)
    }

    @MainActor
    func testRegisterDeviceIncludesStandardAndVoipPushTokens() async throws {
        let config = AppConfig(
            apiBaseURL: URL(string: "https://example.com")!,
            authBaseURL: URL(string: "https://example.com")!,
            hostedSignInURLOverride: nil,
            iosPushEnvironment: "production",
            clerkPublishableKey: nil,
            clerkFrontendAPI: "clerk.example.com",
            sentryDSN: nil,
            appVersion: "1.0",
            buildNumber: "9"
        )

        let session = URLSession(configuration: makeURLSessionConfiguration())
        let client = RotaryAPIClient(config: config, session: session)

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.path, "/api/mobile/devices")
            XCTAssertEqual(request.httpMethod, "POST")

            let bodyData = try XCTUnwrap(self.requestBodyData(for: request))
            let bodyObject = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(bodyObject?["pushToken"] as? String, "standard-token")
            XCTAssertEqual(bodyObject?["voipPushToken"] as? String, "voip-token")
            XCTAssertEqual(bodyObject?["clientReady"] as? Bool, true)

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let responseBody = #"""
            {
              "registration": {
                "id": "dev_1",
                "userId": "user_1",
                "orgId": "org_1",
                "lineCount": 1,
                "platform": "ios",
                "clientReady": true,
                "pushToken": "standard-token",
                "voipPushToken": "voip-token"
              }
            }
            """#.data(using: .utf8)!
            return (response, responseBody)
        }

        let response = try await client.registerDevice(
            token: "session-token",
            pushToken: "standard-token",
            voipPushToken: "voip-token",
            clientReady: true
        )

        XCTAssertEqual(response.registration.pushToken, "standard-token")
        XCTAssertEqual(response.registration.voipPushToken, "voip-token")
    }

    private func makeURLSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }

    private func requestBodyData(for request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }

        return data.isEmpty ? nil : data
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
