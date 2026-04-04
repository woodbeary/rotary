import AVFoundation
import Observation

@MainActor
@Observable
final class RotaryAudioPlayer {
    private var player: AVPlayer?
    private var timeObserver: Any?

    private(set) var currentURL: URL?
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0

    func load(url: URL) {
        if currentURL == url, player != nil {
            return
        }

        reset()
        currentURL = url

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
    }
}
