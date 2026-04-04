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

    private func makeURLSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
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
