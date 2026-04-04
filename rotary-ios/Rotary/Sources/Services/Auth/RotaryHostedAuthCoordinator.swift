import AuthenticationServices
import Foundation
import UIKit

enum RotaryHostedAuthError: LocalizedError {
    case invalidURL
    case missingTicket
    case cancelled
    case unableToStart

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Rotary could not build the hosted sign-in URL."
        case .missingTicket:
            return "Rotary did not receive a valid Clerk sign-in ticket."
        case .cancelled:
            return "Sign-in was cancelled."
        case .unableToStart:
            return "Rotary could not start the sign-in flow."
        }
    }
}

@MainActor
final class RotaryHostedAuthCoordinator: NSObject {
    static let shared = RotaryHostedAuthCoordinator()

    private var session: ASWebAuthenticationSession?

    func startGoogleSignIn() async throws -> String {
        guard let signInURL = AppConfig.shared.hostedClerkSignInURL(provider: "google") else {
            throw RotaryHostedAuthError.invalidURL
        }

        let callbackURL = try await startSession(url: signInURL)
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let ticket = components.queryItems?.first(where: { $0.name == "ticket" })?.value,
              !ticket.isEmpty else {
            throw RotaryHostedAuthError.missingTicket
        }
        return ticket
    }

    private func startSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let callbackScheme = AppConfig.shared.hostedClerkCallbackScheme()
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.session = nil

                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                    return
                }

                if let sessionError = error as? ASWebAuthenticationSessionError,
                   sessionError.code == .canceledLogin {
                    continuation.resume(throwing: RotaryHostedAuthError.cancelled)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(throwing: RotaryHostedAuthError.unableToStart)
            }

            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.session = session

            guard session.start() else {
                self.session = nil
                continuation.resume(throwing: RotaryHostedAuthError.unableToStart)
                return
            }
        }
    }
}

extension RotaryHostedAuthCoordinator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
