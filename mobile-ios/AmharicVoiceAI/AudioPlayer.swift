import AVFoundation
import Foundation

enum AudioPlaybackError: LocalizedError {
    case couldNotPlay
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .couldNotPlay:
            return "The translated audio could not be played."
        case .unsupportedFormat:
            return "The translated audio format is not supported."
        }
    }
}

@MainActor
protocol AudioPlaying: AnyObject {
    func play(data: Data) throws
    func stop()
}

@MainActor
final class TranslatedAudioPlayer: NSObject, AudioPlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play(data: Data) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)

        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else {
                throw AudioPlaybackError.couldNotPlay
            }
            self.player = player
        } catch {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        let playerID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            self?.finishPlayback(for: playerID)
        }
    }

    private func finishPlayback(for playerID: ObjectIdentifier) {
        guard let player, ObjectIdentifier(player) == playerID else { return }
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
