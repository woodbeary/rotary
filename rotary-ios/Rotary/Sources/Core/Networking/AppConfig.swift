import Foundation

enum AppConfigError: LocalizedError {
    case missingInfoValue(String)

    var errorDescription: String? {
        switch self {
        case let .missingInfoValue(key):
            return "Missing required app configuration value: \(key)"
        }
    }
}

struct AppConfig {
    let apiBaseURL: URL
    let authBaseURL: URL
    let hostedSignInURLOverride: URL?
    let iosPushEnvironment: String?
    let clerkPublishableKey: String?
    let clerkFrontendAPI: String
    let sentryDSN: String?
    let appVersion: String
    let buildNumber: String

    nonisolated static let shared = try! AppConfig.load()

    private static func load() throws -> AppConfig {
        let apiBaseURLString = try requiredString("ROTARY_API_BASE_URL")
        guard let apiBaseURL = URL(string: apiBaseURLString) else {
            throw AppConfigError.missingInfoValue("ROTARY_API_BASE_URL")
        }

        let authBaseURL = optionalString("ROTARY_AUTH_BASE_URL")
            .flatMap(URL.init(string:))
            ?? apiBaseURL

        return AppConfig(
            apiBaseURL: apiBaseURL,
            authBaseURL: authBaseURL,
            hostedSignInURLOverride: optionalString("ROTARY_HOSTED_SIGN_IN_URL")
                .flatMap(URL.init(string:)),
            iosPushEnvironment: optionalString("ROTARY_IOS_PUSH_ENVIRONMENT"),
            clerkPublishableKey: optionalString("ROTARY_CLERK_PUBLISHABLE_KEY"),
            clerkFrontendAPI: try requiredString("ROTARY_CLERK_FRONTEND_API"),
            sentryDSN: optionalString("ROTARY_SENTRY_DSN"),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        )
    }

    func hostedClerkSignInURL(provider: String? = nil) -> URL? {
        let baseURL = hostedSignInURLOverride
            ?? authBaseURL.appendingPathComponent("api/mobile/native-auth-start")

        guard var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }

        var queryItemsByName = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item -> (String, URLQueryItem)? in
                guard !item.name.isEmpty else { return nil }
                return (item.name, item)
            }
        )

        let callbackURL = hostedClerkCallbackURL().absoluteString
        queryItemsByName["redirect_url"] = URLQueryItem(
            name: "redirect_url",
            value: callbackURL
        )
        queryItemsByName["redirect_uri"] = URLQueryItem(
            name: "redirect_uri",
            value: callbackURL
        )

        if let provider, !provider.isEmpty {
            queryItemsByName["provider"] = URLQueryItem(name: "provider", value: provider)
        }

        components.queryItems = Array(queryItemsByName.values).sorted { lhs, rhs in
            lhs.name < rhs.name
        }

        return components.url
    }

    func hostedClerkCallbackURL() -> URL {
        URL(string: "rotary://auth")!
    }

    func hostedClerkCallbackScheme() -> String {
        hostedClerkCallbackURL().scheme ?? "rotary"
    }

    func hostedClerkRedirectQueryItems(provider: String? = nil) -> [URLQueryItem] {
        let callbackURL = hostedClerkCallbackURL().absoluteString
        var queryItems = [
            URLQueryItem(name: "redirect_url", value: callbackURL),
            URLQueryItem(name: "redirect_uri", value: callbackURL),
        ]

        if let provider, !provider.isEmpty {
            queryItems.append(URLQueryItem(name: "provider", value: provider))
        }

        return queryItems
    }

    private static func requiredString(_ key: String) throws -> String {
        guard let value = optionalString(key), !value.isEmpty else {
            throw AppConfigError.missingInfoValue(key)
        }
        return value
    }

    private static func optionalString(_ key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
