import UIKit

class SharedMediaDataCell: ModernSelectedBackgroundCell, AttachmentLoadingMessageCell {
    
    @IBOutlet weak var extensionNameLabel: UILabel!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    var viewModel: MessageViewModel?
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        NotificationCenter.default.removeObserver(self)
    }
    
    func render(viewModel: DataMessageViewModel) {
        self.viewModel = viewModel
        if let mediaMimeType = viewModel.message.mediaMimeType {
            extensionNameLabel.text = FileManager.default.pathExtension(mimeType: mediaMimeType)
        }
        titleLabel.text = viewModel.message.name
        let mediaExpired = viewModel.message.mediaStatus == MediaStatus.EXPIRED.rawValue
        subtitleLabel.text = mediaExpired ? Localized.CHAT_FILE_EXPIRED : viewModel.sizeRepresentation
        updateOperationButtonStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
    }
    
    func updateProgress() {
        guard let viewModel = viewModel as? AttachmentLoadingViewModel else {
            return
        }
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
    }
    
    func updateOperationButtonStyle() {
        guard let viewModel = viewModel as? AttachmentLoadingViewModel else {
            return
        }
        operationButton.style = viewModel.operationButtonStyle
        if case .finished(_) = viewModel.operationButtonStyle {
            extensionNameLabel.isHidden = false
        } else {
            extensionNameLabel.isHidden = true
        }
    }
    
    @IBAction func operationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    @objc func conversationDidChange(_ notification: Notification) {
        guard let change = notification.object as? ConversationChange else {
            return
        }
        guard case let .updateDownloadProgress(messageId, progress) = change.action else {
            return
        }
        guard let viewModel = viewModel as? (MessageViewModel & AttachmentLoadingViewModel), messageId == viewModel.message.messageId else {
            return
        }
        viewModel.progress = progress
        updateProgress()
    }
    
}
