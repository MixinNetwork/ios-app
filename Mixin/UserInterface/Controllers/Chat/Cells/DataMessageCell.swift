import UIKit

class DataMessageCell: CardMessageCell, AttachmentLoadingMessageCell {    

    @IBOutlet weak var extensionNameWrapperView: UIView!
    @IBOutlet weak var extensionNameLabel: UILabel!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var filenameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? DataMessageViewModel {
            operationButton.style = viewModel.operationButtonStyle
            if let mediaMimeType = viewModel.message.mediaMimeType {
                extensionNameLabel.text = FileManager.default.pathExtension(mimeType: mediaMimeType)
            }
            filenameLabel.text = viewModel.message.name
            let mediaExpired = viewModel.mediaStatus == MediaStatus.EXPIRED.rawValue
            sizeLabel.text =  mediaExpired ? Localized.CHAT_FILE_EXPIRED : viewModel.sizeRepresentation
        }
    }
    
    @IBAction func operationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    func updateProgress(viewModel: AttachmentLoadingViewModel) {
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
        sizeLabel.text = viewModel.sizeRepresentation
    }
    
}
