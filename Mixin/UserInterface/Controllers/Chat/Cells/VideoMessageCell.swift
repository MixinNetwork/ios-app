import UIKit

class VideoMessageCell: PhotoRepresentableMessageCell, AttachmentExpirationHintingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let operationButton = NetworkOperationButton(type: .custom)
    let expiredHintLabel = UILabel()
    
    override func prepare() {
        super.prepare()
        prepareOperationButtonAndExpiredHintLabel()
        operationButton.addTarget(self, action: #selector(networkOperationAction(_:)), for: .touchUpInside)
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? VideoMessageViewModel {
            renderOperationButtonAndExpiredHintLabel(viewModel: viewModel)
            contentImageView.image = viewModel.betterThumbnail ?? viewModel.thumbnail
        }
    }
    
    @objc func networkOperationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    func updateProgress(viewModel: AttachmentLoadingViewModel) {
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
    }
    
}

