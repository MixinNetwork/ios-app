import UIKit

protocol AudioMessageCellDelegate: class {
    func audioMessageCellDidTogglePlaying(_ cell: AudioMessageCell)
}

class AudioMessageCell: CardMessageCell, AttachmentLoadingMessageCell {
    
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var waveformView: WaveformView!
    @IBOutlet weak var lengthLabel: UILabel!
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    weak var audioPlaybackDelegate: AudioMessageCellDelegate?
    
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else {
                return
            }
            let image = isPlaying ? #imageLiteral(resourceName: "ic_file_cancel") : #imageLiteral(resourceName: "ic_play")
            playButton.setImage(image, for: .normal)
        }
    }
    
    override var contentTopMargin: CGFloat {
        return 10
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isPlaying = false
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AudioMessageViewModel {
            lengthLabel.text = viewModel.length
            waveformView.waveform = viewModel.waveform
            operationButton.style = viewModel.operationButtonStyle
            operationButton.isHidden = viewModel.operationButtonIsHidden
            playButton.isHidden = viewModel.playButtonIsHidden
            let player = MXNAudioPlayer.shared()
            if player.state == .playing, let mediaUrl = viewModel.message.mediaUrl, player.path.contains(mediaUrl) {
                isPlaying = true
            }
        }
    }
    
    @IBAction func operationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    @IBAction func playAction(_ sender: Any) {
        audioPlaybackDelegate?.audioMessageCellDidTogglePlaying(self)
    }
    
    func updateProgress(viewModel: AttachmentLoadingViewModel) {
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
    }
    
}
