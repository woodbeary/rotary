import Foundation
import Observation

enum InferenceMode: String, CaseIterable, Codable, Identifiable {
    case cloud
    case local

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cloud:
            return "Cloud"
        case .local:
            return "Local"
        }
    }

    var subtitle: String {
        switch self {
        case .cloud:
            return "Runs on Rotary servers"
        case .local:
            return "Runs on this iPhone"
        }
    }
}

@MainActor
@Observable
final class InferenceModeStore {
    private static let defaultsKey = "rotary.inferenceMode"

    static let shared = InferenceModeStore()

    private let defaults: UserDefaults

    var mode: InferenceMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Self.defaultsKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.defaultsKey),
           let savedMode = InferenceMode(rawValue: rawValue) {
            mode = savedMode
        } else {
            mode = .cloud
        }
    }

    var isLocalMode: Bool {
        mode == .local
    }
}
