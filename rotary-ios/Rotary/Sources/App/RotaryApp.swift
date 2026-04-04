import SwiftUI

@main
struct RotaryApp: App {
    @UIApplicationDelegateAdaptor(RotaryAppDelegate.self) private var appDelegate
    @AppStorage(RotaryAppearanceMode.storageKey) private var appearanceModeRawValue = RotaryAppearanceMode.system.rawValue

    init() {
        if !ProcessInfo.isRunningRotaryUnitTests {
            RotaryRuntimeDiagnostics.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.isRunningRotaryUnitTests {
                Color.clear
            } else {
                RotaryRootView(appearanceMode: appearanceModeBinding)
                    .preferredColorScheme(preferredColorScheme)
            }
        }
    }

    private var appearanceMode: RotaryAppearanceMode {
        RotaryAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var appearanceModeBinding: Binding<RotaryAppearanceMode> {
        Binding(
            get: { appearanceMode },
            set: { newValue in
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    appearanceModeRawValue = newValue.rawValue
                }
            }
        )
    }

    private var preferredColorScheme: ColorScheme? {
        if let debugOverride = RotaryDebugAppearanceOverride.current {
            return debugOverride
        }

        return appearanceMode.preferredColorScheme
    }
}

extension ProcessInfo {
    static var isRunningRotaryUnitTests: Bool {
        processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

private enum RotaryDebugAppearanceOverride {
    static var current: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-rotary-force-dark") {
            return .dark
        }
        if arguments.contains("-rotary-force-light") {
            return .light
        }
        return nil
    }
}
