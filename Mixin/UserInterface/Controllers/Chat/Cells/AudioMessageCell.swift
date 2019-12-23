import UIKit
import MixinServices

class AudioMessageCell: CardMessageCell, AttachmentLoadingMessageCell, AudioCell {
    
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var playbackStateWrapperView: UIView!
    @IBOutlet weak var playbackStateImageView: UIImageView!
    @IBOutlet weak var waveformView: WaveformView!
    @IBOutlet weak var highlightedWaveformView: WaveformView!
    @IBOutlet weak var lengthLabel: UILabel!
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    private let waveformMaskView = UIView()
    private let waveformUpdateInterval: TimeInterval = 0.1
    
    private var timer: Timer?
    private var duration: Float64 = 0
    
    var style: AudioCellStyle = .stopped {
        didSet {
            timer?.invalidate()
            timer = nil
            switch style {
            case .playing:
                playbackStateImageView.image = R.image.ic_pause()
                updateWaveformProgress()
                timer = Timer(timeInterval: waveformUpdateInterval, repeats: true, block: { [weak self] (_) in
                    self?.updateWaveformProgress()
                })
                RunLoop.main.add(timer!, forMode: .common)
            case .stopped:
                playbackStateImageView.image = R.image.ic_play()
                waveformMaskView.frame = .zero
            case .paused:
                playbackStateImageView.image = R.image.ic_play()
                updateWaveformProgress()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        if let messageId = viewModel?.message.messageId {
            AudioManager.shared.unregister(cell: self, forMessageId: messageId)
        }
    }
    
    override var contentTopMargin: CGFloat {
        return 10
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        waveformMaskView.backgroundColor = .black
        highlightedWaveformView.mask = waveformMaskView
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        style = .stopped
        waveformMaskView.frame = .zero
        timer?.invalidate()
        timer = nil
        if let messageId = viewModel?.message.messageId {
            AudioManager.shared.unregister(cell: self, forMessageId: messageId)
        }
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AudioMessageViewModel {
            lengthLabel.text = viewModel.length
            waveformView.waveform = viewModel.waveform
            highlightedWaveformView.waveform = viewModel.waveform
            updateOperationButtonStyle()
            operationButton.isHidden = viewModel.operationButtonIsHidden
            playbackStateWrapperView.isHidden = viewModel.playbackStateIsHidden
            duration = Float64(viewModel.message.mediaDuration ?? 0)
            updateUnreadStyle()
        }
        AudioManager.shared.register(cell: self, forMessageId: viewModel.message.messageId)
    }
    
    @IBAction func operationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    func updateOperationButtonStyle() {
        guard let viewModel = viewModel as? AudioMessageViewModel else {
            return
        }
        operationButton.style = viewModel.operationButtonStyle
        operationButton.isHidden = viewModel.operationButtonIsHidden
        playbackStateWrapperView.isHidden = viewModel.playbackStateIsHidden
    }
    
    func updateUnreadStyle() {
        guard let viewModel = viewModel as? AudioMessageViewModel else {
            return
        }
        if viewModel.isUnread {
            waveformView.tintColor = .highlightedText
            lengthLabel.textColor = .highlightedText
        } else {
            waveformView.tintColor = .accessoryText
            lengthLabel.textColor = .accessoryText
        }
    }
    
    private func updateWaveformProgress() {
        guard let player = AudioManager.shared.player, AudioManager.shared.playingMessage?.messageId == viewModel?.message.messageId else {
            return
        }
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
