import UIKit

class SharedMediaAudioCell: UITableViewCell, AudioCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var networkOperationButton: LargeModernNetworkOperationButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var waveformView: WaveformView!
    @IBOutlet weak var highlightedWaveformView: WaveformView!
    @IBOutlet weak var lengthLabel: UILabel!
    
    weak var audioManager: SharedMediaAudioManager?
    
    private let waveformMaskView = UIView()
    private let waveformUpdateInterval: TimeInterval = 0.1
    
    private var timer: Timer?
    private var audio: SharedMediaAudio?
    
    var style: AudioCellStyle = .stopped {
        didSet {
            timer?.invalidate()
            timer = nil
            switch style {
            case .playing:
                playButton.setImage(R.image.ic_file_cancel(), for: .normal)
                updateWaveformProgress()
                timer = Timer(timeInterval: waveformUpdateInterval, repeats: true, block: { [weak self] (_) in
                    self?.updateWaveformProgress()
                })
                RunLoop.main.add(timer!, forMode: .common)
            case .stopped:
                playButton.setImage(R.image.ic_play(), for: .normal)
                waveformMaskView.frame = .zero
            case .paused:
                playButton.setImage(R.image.ic_play(), for: .normal)
                updateWaveformProgress()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        waveformMaskView.backgroundColor = .black
        highlightedWaveformView.mask = waveformMaskView
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
        audio = nil
        waveformMaskView.frame = .zero
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    func render(audio: SharedMediaAudio) {
        self.audio = audio
        if let avatarUrl = audio.message.userAvatarUrl {
            avatarImageView.setImage(with: avatarUrl,
                                     userId: audio.message.userId,
                                     name: audio.message.userFullName)
        }
        lengthLabel.text = audio.length
        waveformView.waveform = audio.mediaWaveform
        highlightedWaveformView.waveform = audio.mediaWaveform
        update(with: audio.mediaStatus)
        updateUnreadStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
    }
    
    func update(with mediaStatus: MediaStatus) {
        switch mediaStatus {
        case .PENDING, .CANCELED:
            networkOperationButton.style = .busy(progress: audio?.progress ?? 0)
            networkOperationButton.isHidden = false
            playButton.isHidden = true
        case .DONE, .READ:
            networkOperationButton.style = .finished(showPlayIcon: false)
            networkOperationButton.isHidden = true
            playButton.isHidden = false
        case .EXPIRED:
            networkOperationButton.style = .expired
            networkOperationButton.isHidden = false
            playButton.isHidden = true
        }
    }
    
    func updateUnreadStyle() {
        guard let audio = audio else {
            return
        }
        if audio.mediaStatus == .DONE && !audio.isSentByMe {
            waveformView.tintColor = .highlightedText
            lengthLabel.textColor = .highlightedText
        } else {
            waveformView.tintColor = .disabledGray
            lengthLabel.textColor = UIColor(displayP3RgbValue: 0xB8BDC7)
        }
    }
    
    @objc func conversationDidChange(_ notification: Notification) {
        guard let change = notification.object as? ConversationChange else {
            return
        }
        guard case let .updateDownloadProgress(messageId, progress) = change.action else {
            return
        }
        guard let audio = audio, audio.messageId == messageId else {
            return
        }
        audio.progress = progress
        networkOperationButton.style = .busy(progress: audio.progress ?? 0)
    }
    
    private func updateWaveformProgress() {
        guard let audio = audio, let manager = audioManager, let player = manager.player, manager.playingMessage?.messageId == audio.messageId else {
            return
        }
        let duration = Double(audio.duration) * millisecondsPerSecond
        let progress = player.currentTime * millisecondsPerSecond / (duration - waveformUpdateInterval * millisecondsPerSecond)
        let oldWidth = waveformMaskView.frame.width
        let newWidth = highlightedWaveformView.frame.width * CGFloat(progress)
        if abs(oldWidth - newWidth) > 0.3 {
            let size = CGSize(width: newWidth, height: highlightedWaveformView.frame.height)
            UIView.animate(withDuration: waveformUpdateInterval) {
                self.waveformMaskView.frame = CGRect(origin: .zero, size: size)
            }
        }
    }
    
}
