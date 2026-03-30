import Foundation
import AVFoundation

final class AudioPlayer {
    static let shared = AudioPlayer()

    private var volume: Float = 0.8
    private var countdownPlayer: AVAudioPlayer?
    private var effectPlayer: AVAudioPlayer?
    private var warningPlayer: AVAudioPlayer?

    private init() {}

    func setVolume(_ newVolume: Float) {
        let clamped = max(0, min(1, newVolume))
        volume = clamped
        countdownPlayer?.volume = clamped
        effectPlayer?.volume = clamped
        warningPlayer?.volume = clamped
    }

    func startCountdown(named name: String) {
        guard let player = makePlayer(named: name) else { return }
        countdownPlayer?.stop()
        countdownPlayer = player
        countdownPlayer?.numberOfLoops = -1
        countdownPlayer?.currentTime = 0
        countdownPlayer?.volume = volume
        countdownPlayer?.prepareToPlay()
        countdownPlayer?.play()
    }

    func stopCountdown() {
        countdownPlayer?.stop()
        countdownPlayer = nil
    }

    func startWarning(named name: String) {
        guard let player = makePlayer(named: name) else { return }
        warningPlayer?.stop()
        warningPlayer = player
        warningPlayer?.numberOfLoops = -1
        warningPlayer?.currentTime = 0
        warningPlayer?.volume = volume
        warningPlayer?.prepareToPlay()
        warningPlayer?.play()
    }

    func stopWarning() {
        warningPlayer?.stop()
        warningPlayer = nil
    }

    func playEffect(named name: String) {
        guard let player = makePlayer(named: name) else { return }
        effectPlayer?.stop()
        effectPlayer = player
        effectPlayer?.numberOfLoops = 0
        effectPlayer?.currentTime = 0
        effectPlayer?.volume = volume
        effectPlayer?.prepareToPlay()
        effectPlayer?.play()
    }

    private func makePlayer(named name: String) -> AVAudioPlayer? {
        for (url, hint) in resourceCandidates(for: name) {
            do {
                if let hint {
                    return try AVAudioPlayer(contentsOf: url, fileTypeHint: hint)
                } else {
                    return try AVAudioPlayer(contentsOf: url)
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func resourceCandidates(for name: String) -> [(URL, String?)] {
        let bundleCandidates = [Bundle.module, Bundle.main]
        var urls: [(URL, String?)] = []

        for bundle in bundleCandidates {
            if let mp3 = bundle.url(forResource: name, withExtension: "mp3") {
                urls.append((mp3, nil))
                urls.append((mp3, AVFileType.wav.rawValue))
            }
            if let wav = bundle.url(forResource: name, withExtension: "wav") {
                urls.append((wav, nil))
            }
        }

        return urls
    }
}
