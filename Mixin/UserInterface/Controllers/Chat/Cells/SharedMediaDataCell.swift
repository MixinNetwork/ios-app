import UIKit

class SharedMediaDataCell: ModernSelectedBackgroundCell, AttachmentLoadingMessageCell {
    
    @IBOutlet weak var extensionNameLabel: UILabel!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    var viewModel: MessageViewModel?
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    func render(viewModel: DataMessageViewModel) {
        self.viewModel = viewModel
        if let mediaMimeType = viewModel.message.mediaMimeType {
            extensionNameLabel.text = FileManager.default.pathExtension(mimeType: mediaMimeType)
        }
        titleLabel.text = viewModel.message.name
        let mediaExpired = viewModel.message.mediaStatus == MediaStatus.EXPIRED.rawValue
        subtitleLabel.text = mediaExpired ? Localized.CHAT_FILE_EXPIRED : viewModel.sizeRepresentation
        updateOperationButtonStyle()
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
    
}
