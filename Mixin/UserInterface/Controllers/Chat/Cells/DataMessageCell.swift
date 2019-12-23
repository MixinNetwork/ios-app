import UIKit
import MixinServices

class DataMessageCell: CardMessageCell, AttachmentLoadingMessageCell {    

    @IBOutlet weak var extensionNameWrapperView: UIView!
    @IBOutlet weak var extensionNameLabel: UILabel!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var filenameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        sizeLabel.snp.makeConstraints { (make) in
            make.trailing.equalTo(timeLabel.snp.leading)
        }
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? DataMessageViewModel {
            updateOperationButtonStyle()
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
    
    func updateProgress() {
        guard let viewModel = viewModel as? AttachmentLoadingViewModel else {
            return
        }
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
        sizeLabel.text = viewModel.sizeRepresentation
    }
    
}
