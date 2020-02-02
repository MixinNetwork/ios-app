import UIKit
import MediaPlayer
import SDWebImage
import MixinServices

protocol SharedMediaAudioManagerDelegate: class {
    func sharedMediaAudioManager(_ manager: SharedMediaAudioManager, playableMessageNextTo message: MessageItem) -> MessageItem?
    func sharedMediaAudioManager(_ manager: SharedMediaAudioManager, playableMessagePreviousTo message: MessageItem) -> MessageItem?
}

class SharedMediaAudioManager: AudioManager {
    
    weak var delegate: SharedMediaAudioManagerDelegate?
    
    private var needsUpdatePlayingInfo = false
    
    deinit {
        removePlayingInfoAndRemoteCommandTarget()
    }
    
    override func play(message: MessageItem) {
        if message.messageId != playingMessage?.messageId {
            needsUpdatePlayingInfo = true
        }
        super.play(message: message)
    }
    
    override func playableMessage(nextTo message: MessageItem) -> MessageItem? {
        return delegate?.sharedMediaAudioManager(self, playableMessageNextTo: message)
    }
    
    override func preloadAudio(nextTo message: MessageItem) {
        guard let next = delegate?.sharedMediaAudioManager(self, playableMessageNextTo: message) else {
            return
        }
        guard next.category.hasSuffix("_AUDIO"), next.mediaStatus == MediaStatus.CANCELED.rawValue || next.mediaStatus == MediaStatus.PENDING.rawValue else {
            return
        }
        let job = AudioDownloadJob(messageId: next.messageId, mediaMimeType: next.mediaMimeType)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    override func handleStatusChange(player: AudioPlayer) {
        super.handleStatusChange(player: player)
        if #available(iOS 13.0, *) {
            let center = MPNowPlayingInfoCenter.default()
            switch player.status {
            case .playing:
                center.playbackState = .playing
            case .paused:
                center.playbackState = .paused
            case .readyToPlay:
                break
            case .didReachEnd:
                center.playbackState = .stopped
            }
        }
        switch player.status {
        case .playing:
            if needsUpdatePlayingInfo {
                resetPlayingInfoAndRemoteCommandTarget(player: player)
                needsUpdatePlayingInfo = false
            }
        case .paused:
            updateNowPlayingInfoElapsedPlaybackTime()
        case .didReachEnd:
            removePlayingInfoAndRemoteCommandTarget()
        default:
            break
        }
    }
    
    private func resetPlayingInfoAndRemoteCommandTarget(player: AudioPlayer) {
        removePlayingInfoAndRemoteCommandTarget()
        guard let message = playingMessage else {
            return
        }
        let artwork: MPMediaItemArtwork? = {
            guard let userAvatarUrl = message.userAvatarUrl, let url = URL(string: userAvatarUrl) else {
                return nil
            }
            return MPMediaItemArtwork(boundsSize: CGSize(width: 512, height: 512)) { (_) -> UIImage in
                let semaphore = DispatchSemaphore(value: 0)
                var image: UIImage?
                SDWebImageManager.shared.loadImage(with: url, options: .fromCacheOnly, progress: nil) { (img, _, _, _, _, _) in
                    image = img
                    semaphore.signal()
                }
                semaphore.wait()
                return image ?? UIImage()
            }
        }()
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: R.string.localizable.chat_media_category_audio()
        ]
        if let username = playingMessage?.userFullName {
            info[MPMediaItemPropertyArtist] = username
        }
        if let duration = playingMessage?.mediaDuration {
            let interval = TimeInterval(duration) / 1000
            info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: interval)
            info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: 1.0)
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: player.currentTime)
        }
        if let artwork = artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        let center = MPRemoteCommandCenter.shared()
        func setCommandEnabled(_ command: MPRemoteCommand, with action: Selector) {
            command.isEnabled = true
            command.addTarget(self, action: action)
        }
        setCommandEnabled(center.playCommand, with: #selector(playCommand(_:)))
        setCommandEnabled(center.pauseCommand, with: #selector(pauseCommand(_:)))
        setCommandEnabled(center.stopCommand, with: #selector(stopCommand(_:)))
        setCommandEnabled(center.nextTrackCommand, with: #selector(nextTrackCommand(_:)))
        setCommandEnabled(center.previousTrackCommand, with: #selector(previousTrackCommand(_:)))
    }
    
    private func removePlayingInfoAndRemoteCommandTarget() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.stopCommand] {
            command.isEnabled = false
            command.removeTarget(self)
        }
    }
    
    private func updateNowPlayingInfoElapsedPlaybackTime() {
        let center = MPNowPlayingInfoCenter.default()
        guard let time = player?.currentTime, var info = center.nowPlayingInfo else {
            return
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: time)
        center.nowPlayingInfo = info
    }
    
}

extension SharedMediaAudioManager {
    
    @objc private func playCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if let message = playingMessage {
            play(message: message)
            return .success
        } else {
            return .noActionableNowPlayingItem
        }
    }
    
    @objc private func pauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        pause()
        return .success
    }
    
    @objc private func stopCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        stop()
        return .success
    }
    
    @objc private func nextTrackCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if let current = playingMessage {
            if let next = delegate?.sharedMediaAudioManager(self, playableMessageNextTo: current) {
                let userInfo = [AudioManager.conversationIdUserInfoKey: next.conversationId,
                                AudioManager.messageIdUserInfoKey: next.messageId]
                NotificationCenter.default.post(name: AudioManager.willPlayNextNotification, object: self, userInfo: userInfo)
                play(message: next)
                return .success
            } else {
                return .noSuchContent
            }
        } else {
            return .noActionableNowPlayingItem
        }
    }
    
    @objc private func previousTrackCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if let current = playingMessage {
            if let previous = delegate?.sharedMediaAudioManager(self, playableMessagePreviousTo: current) {
                let userInfo = [AudioManager.conversationIdUserInfoKey: previous.conversationId,
                                AudioManager.messageIdUserInfoKey: previous.messageId]
                NotificationCenter.default.post(name: AudioManager.willPlayPreviousNotification, object: self, userInfo: userInfo)
                play(message: previous)
                return .success
            } else {
                return .noSuchContent
            }
        } else {
            return .noActionableNowPlayingItem
        }
    }
    
}
