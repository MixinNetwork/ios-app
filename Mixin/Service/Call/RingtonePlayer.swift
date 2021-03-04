import Foundation
import AVFoundation.AVFAudio

class RingtonePlayer {
    
    enum Ringtone {
        case incoming
        case outgoing
    }
    
    private lazy var incomingPlayer: AVAudioPlayer? = {
        guard let player = try? AVAudioPlayer(contentsOf: R.file.callCaf()!) else {
            return nil
        }
        player.numberOfLoops = -1
        player.volume = 1
        incomingPlayerIfLoaded = player
        return player
    }()
    
    private lazy var outgoingPlayer: AVAudioPlayer? = {
        guard let player = try? AVAudioPlayer(contentsOf: R.file.ringtone_outgoingCaf()!) else {
            return nil
        }
        player.numberOfLoops = -1
        player.volume = 1
        outgoingPlayerIfLoaded = player
        return player
    }()
    
    private weak var incomingPlayerIfLoaded: AVAudioPlayer?
    private weak var outgoingPlayerIfLoaded: AVAudioPlayer?
    
    func play(ringtone: Ringtone) {
        stop()
        let audioSession = AudioSession.shared.avAudioSession
        let options: AVAudioSession.CategoryOptions = [
            .duckOthers, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay
        ]
        let player: AVAudioPlayer?
        switch ringtone {
        case .incoming:
            try? audioSession.setCategory(.playback, mode: .default, options: options)
            player = incomingPlayer
        case .outgoing:
            try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: options)
            player = outgoingPlayer
        }
        if let player = player {
            player.currentTime = 0
            player.play()
        }
    }
    
    func stop() {
        incomingPlayerIfLoaded?.stop()
        outgoingPlayerIfLoaded?.stop()
    }
    
}
