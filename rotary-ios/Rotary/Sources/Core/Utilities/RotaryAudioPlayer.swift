import AVFoundation
import Observation

enum RotaryPlaybackAudioRoute: String {
    case speaker
    case receiver

    var systemImage: String {
        switch self {
        case .speaker:
            return "speaker.wave.2.fill"
        case .receiver:
            return "phone.fill"
        }
    }

    var title: String {
        switch self {
        case .speaker:
            return "Speaker"
        case .receiver:
            return "Receiver"
        }
    }
}

@MainActor
@Observable
final class RotaryAudioPlayer {
    private var player: AVPlayer?
    private var timeObserver: Any?

    private(set) var currentURL: URL?
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    private(set) var audioRoute: RotaryPlaybackAudioRoute = .speaker

    func load(url: URL) {
        if currentURL == url, player != nil {
            return
        }

        reset()
        currentURL = url
        configureAudioSession()
        applyAudioRoute(.speaker)

        let player = AVPlayer(url: url)
        self.player = player

        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self, weak player] time in
            let nextCurrentTime = time.seconds.isFinite ? time.seconds : 0
            let itemDuration = player?.currentItem?.duration.seconds ?? 0
            let nextDuration = itemDuration.isFinite ? max(itemDuration, 0) : 0
            let nextIsPlaying = player?.timeControlStatus == .playing

            Task { @MainActor [weak self] in
                guard let self else { return }
                currentTime = nextCurrentTime
                duration = nextDuration
                isPlaying = nextIsPlaying
            }
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
    }

    func stop() {
        player?.pause()
        isPlaying = false
        seek(to: 0)
        resetAudioRoute()
    }

    func stopAndResetAudioRoute() {
        stop()
        reset()
    }

    func toggleAudioRoute() {
        let nextRoute: RotaryPlaybackAudioRoute = (audioRoute == .speaker) ? .receiver : .speaker
        applyAudioRoute(nextRoute)
    }

    private func reset() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
        timeObserver = nil
        currentURL = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        resetAudioRoute()
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try audioSession.setActive(true, options: [])
        } catch {
            // Playback still works with system defaults; route toggling may be unavailable.
        }
    }

    private func applyAudioRoute(_ route: RotaryPlaybackAudioRoute) {
        audioRoute = route
        let audioSession = AVAudioSession.sharedInstance()
        do {
            switch route {
            case .speaker:
                try audioSession.overrideOutputAudioPort(.speaker)
            case .receiver:
                try audioSession.overrideOutputAudioPort(.none)
            }
        } catch {
            // Keep rendering state stable even if hardware route switching fails.
        }
    }

    private func resetAudioRoute() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.overrideOutputAudioPort(.none)
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // No-op.
        }
        audioRoute = .speaker
    }
}
