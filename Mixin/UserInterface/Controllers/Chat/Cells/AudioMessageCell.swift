import UIKit

class AudioMessageCell: CardMessageCell, AttachmentLoadingMessageCell {
    
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var playbackStateImageView: UIImageView!
    @IBOutlet weak var waveformView: WaveformView!
    @IBOutlet weak var highlightedWaveformView: WaveformView!
    @IBOutlet weak var lengthLabel: UILabel!
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    private let waveformMaskView = UIView()
    private let waveformUpdateInterval: TimeInterval = 0.1
    
    private var timer: Timer?
    private var duration: Float64 = 0
    
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else {
                return
            }
            let image = isPlaying ? #imageLiteral(resourceName: "ic_file_cancel") : #imageLiteral(resourceName: "ic_play")
            playbackStateImageView.image = image
            if isPlaying {
                MXNAudioPlayer.shared().addObserver(self)
                timer = Timer(timeInterval: waveformUpdateInterval, repeats: true, block: { [weak self] (_) in
                    self?.updateWaveformProgress()
                })
                RunLoop.main.add(timer!, forMode: .commonModes)
            } else {
                MXNAudioPlayer.shared().removeObserver(self)
                waveformMaskView.frame = .zero
                timer?.invalidate()
                timer = nil
            }
        }
    }
        
    deinit {
        timer?.invalidate()
        timer = nil
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
        isPlaying = false
        waveformMaskView.frame = .zero
        MXNAudioPlayer.shared().removeObserver(self)
        timer?.invalidate()
        timer = nil
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AudioMessageViewModel {
            lengthLabel.text = viewModel.length
            waveformView.waveform = viewModel.waveform
            highlightedWaveformView.waveform = viewModel.waveform
            operationButton.style = viewModel.operationButtonStyle
            operationButton.isHidden = viewModel.operationButtonIsHidden
            playbackStateImageView.isHidden = viewModel.playbackStateIsHidden
            duration = Float64(viewModel.message.mediaDuration ?? 0)
            let player = MXNAudioPlayer.shared()
            if player.state == .playing, let mediaUrl = viewModel.message.mediaUrl, player.path.contains(mediaUrl) {
                isPlaying = true
            }
        }
    }
    
    @IBAction func operationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    func updateProgress(viewModel: AttachmentLoadingViewModel) {
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
    }
    
    private func updateWaveformProgress() {
        let progress = MXNAudioPlayer.shared().currentTime * millisecondsPerSecond / (duration - waveformUpdateInterval * millisecondsPerSecond)
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

extension AudioMessageCell: MXNAudioPlayerObserver {
    
    func mxnAudioPlayer(_ player: MXNAudioPlayer, playbackStateDidChangeTo state: MXNAudioPlaybackState) {
        if state == .stopped {
            if Thread.isMainThread {
                isPlaying = false
            } else {
                DispatchQueue.main.sync { [weak self] in
                    self?.isPlaying = false
                }
            }
        }
    }
    
}
