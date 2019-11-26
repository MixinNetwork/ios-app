import Foundation

class SharedMediaAudio {
    
    let message: MessageItem
    let duration: Int
    let mediaWaveform: Waveform
    let length: String
    let isSentByMe: Bool
    
    var progress: Double?
    var mediaStatus: MediaStatus {
        get {
            if let status = message.mediaStatus {
                return MediaStatus(rawValue: status) ?? .PENDING
            } else {
                return .PENDING
            }
        }
        set {
            message.mediaStatus = newValue.rawValue
        }
    }
    
    init(message: MessageItem) {
        self.message = message
        duration = Int(round(Double(message.mediaDuration ?? 0) / millisecondsPerSecond))
        self.mediaWaveform = Waveform(data: message.mediaWaveform, durationInSeconds: duration)
        self.length = mediaDurationFormatter.string(from: TimeInterval(duration)) ?? ""
        self.isSentByMe = message.userId == AccountAPI.shared.accountUserId
    }
    
}

extension SharedMediaAudio: SharedMediaItem {
    
    var messageId: String {
        return message.messageId
    }
    
    var createdAt: String {
        return message.createdAt
    }
    
}
