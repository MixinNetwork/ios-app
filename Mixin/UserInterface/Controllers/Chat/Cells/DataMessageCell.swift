import UIKit
import MixinServices

class DataMessageCell: CardMessageCell<DataMessageExtensionIconView, CardMessageTitleView>, AttachmentLoadingMessageCell, AudioCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    var operationButton: NetworkOperationButton! {
        leftView.operationButton
    }
    
    var style: AudioCellStyle = .stopped {
        didSet {
            guard let mediaStatus = (viewModel as? DataMessageViewModel)?.mediaStatus else {
                return
            }
            guard mediaStatus == MediaStatus.DONE.rawValue || mediaStatus == MediaStatus.READ.rawValue else {
                return
            }
            switch style {
            case .playing:
                operationButton.setImage(R.image.ic_pause(), for: .normal)
            case .stopped, .paused:
                operationButton.setImage(R.image.ic_play(), for: .normal)
            }
        }
    }
    
    deinit {
        if let viewModel = viewModel as? DataMessageViewModel, viewModel.isListPlayable {
            PlaylistManager.shared.unregister(cell: self, for: viewModel.message.messageId)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        style = .stopped
        if let viewModel = viewModel as? DataMessageViewModel, viewModel.isListPlayable {
            PlaylistManager.shared.unregister(cell: self, for: viewModel.message.messageId)
        }
    }
    
    override func prepare() {
        super.prepare()
        leftView.extensionNameWrapperView.layer.cornerRadius = DataMessageViewModel.leftViewSideLength / 2
        leftView.extensionNameWrapperView.clipsToBounds = true
        operationButton.addTarget(self,
                                  action: #selector(operationAction(_:)),
                                  for: .touchUpInside)
        titleLabel.textColor = .text
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .accessoryText
        subtitleLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        subtitleLabel.adjustsFontForContentSizeCategory = true
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? DataMessageViewModel {
            updateOperationButtonStyle()
            if let mime = viewModel.message.mediaMimeType, let name = FileManager.default.pathExtension(mimeType: mime) {
                leftView.extensionNameLabel.text = name
            } else {
                leftView.extensionNameLabel.text = "FILE"
            }
            titleLabel.text = viewModel.message.name ?? " "
            let mediaExpired = viewModel.mediaStatus == MediaStatus.EXPIRED.rawValue
            subtitleLabel.text =  mediaExpired ? Localized.CHAT_FILE_EXPIRED : viewModel.sizeRepresentation
            if viewModel.isListPlayable {
                PlaylistManager.shared.register(cell: self, for: viewModel.message.messageId)
            }
        }
    }
    
    @objc func operationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    func updateProgress() {
        guard let viewModel = viewModel as? AttachmentLoadingViewModel else {
            return
        }
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
        subtitleLabel.text = viewModel.sizeRepresentation
    }
    
}
