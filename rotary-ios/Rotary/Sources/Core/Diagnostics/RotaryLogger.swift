import Foundation
import Observation
import OSLog
#if canImport(Sentry)
import Sentry
#endif

struct RotaryTraceEvent: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let level: String
    let message: String
}

@MainActor
@Observable
final class RotaryTraceStore {
    static let shared = RotaryTraceStore()

    private(set) var events: [RotaryTraceEvent] = []

    func record(category: String, level: String, message: String) {
        events.insert(
            RotaryTraceEvent(
                timestamp: Date(),
                category: category,
                level: level,
                message: message
            ),
            at: 0
        )
        if events.count > 200 {
            events.removeLast(events.count - 200)
        }
    }

    func exportText(limit: Int = 120) -> String {
        events
            .prefix(limit)
            .map { event in
                let timestamp = event.timestamp.formatted(.dateTime.hour().minute().second())
                return "[\(timestamp)] [\(event.category)] [\(event.level)] \(event.message)"
            }
            .joined(separator: "\n")
    }
}

private struct RotaryDiagnosticsPayload: Encodable {
    let severity: String
    let stage: String
    let message: String
    let context: [String: String]?
    let bootTrace: String?
    let appVersion: String?
    let buildNumber: String?
    let platform: String?
    let runtime: String?
}

enum RotaryRuntimeDiagnostics {
    static func bootstrap() {
        RotaryDiagnosticsReporter.record(
            category: "diagnostics",
            level: "info",
            message: "runtime diagnostics boot"
        )

#if canImport(Sentry)
        guard let dsn = AppConfig.shared.sentryDSN, !dsn.isEmpty else {
            RotaryLogger.trace("sentry dsn is empty for this build", category: "diagnostics")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.enableAutoSessionTracking = true
            options.enableAppHangTracking = true
            options.tracesSampleRate = 1.0
            options.profilesSampleRate = 1.0
        }
        RotaryLogger.trace("sentry initialized", category: "diagnostics")
#else
        RotaryLogger.trace("sentry sdk not linked into this build", category: "diagnostics")
#endif
    }
}

enum RotaryDiagnosticsReporter {
    static func record(category: String, level: String = "info", message: String) {
        Task { @MainActor in
            RotaryTraceStore.shared.record(category: category, level: level, message: message)
        }
    }

    static func send(
        severity: String = "error",
        stage: String,
        message: String,
        context: [String: String] = [:],
        authToken: String? = nil
    ) {
        Task(priority: .utility) {
            guard let url = URL(string: "/api/mobile/diagnostics", relativeTo: AppConfig.shared.apiBaseURL) else {
                return
            }

            let bootTrace = await MainActor.run {
                RotaryTraceStore.shared.exportText(limit: 80)
            }

            let payload = RotaryDiagnosticsPayload(
                severity: severity,
                stage: stage,
                message: message,
                context: context.isEmpty ? nil : context,
                bootTrace: bootTrace.isEmpty ? nil : bootTrace,
                appVersion: AppConfig.shared.appVersion,
                buildNumber: AppConfig.shared.buildNumber,
                platform: "ios",
                runtime: "swiftui"
            )

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 8
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let authToken, !authToken.isEmpty {
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = try? JSONEncoder().encode(payload)

            do {
                _ = try await URLSession.shared.data(for: request)
            } catch {
                record(
                    category: "diagnostics",
                    level: "warning",
                    message: "remote diagnostics failed: \(error.localizedDescription)"
                )
            }
        }
    }
}

enum RotaryLogger {
    static let subsystem = "com.theinterpretingapp.rotary"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let api = Logger(subsystem: subsystem, category: "api")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let voice = Logger(subsystem: subsystem, category: "voice")

    static func trace(_ message: String, category: String = "app", level: String = "info") {
        print("[Rotary] \(message)")
        RotaryDiagnosticsReporter.record(category: category, level: level, message: message)
    }
}
