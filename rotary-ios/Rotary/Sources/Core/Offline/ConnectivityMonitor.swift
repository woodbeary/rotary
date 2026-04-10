import Foundation
import Network
import Observation

extension Notification.Name {
    static let rotaryConnectivityChanged = Notification.Name("rotaryConnectivityChanged")
}

@MainActor
@Observable
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    var isOnline = true
    var lastTransitionAt = Date()

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        queue = DispatchQueue(label: "com.rotary.connectivity-monitor", qos: .utility)

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.update(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func update(path: NWPath) {
        let nextOnline = path.status == .satisfied
        guard nextOnline != isOnline else { return }

        isOnline = nextOnline
        lastTransitionAt = Date()

        NotificationCenter.default.post(name: .rotaryConnectivityChanged, object: self)
    }

    func forceStateForTesting(_ online: Bool) {
        guard online != isOnline else { return }
        isOnline = online
        lastTransitionAt = Date()
        NotificationCenter.default.post(name: .rotaryConnectivityChanged, object: self)
    }
}
