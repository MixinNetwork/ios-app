import UIKit

protocol AttachmentLoadingMessageCellDelegate: class {
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: MessageCell & AttachmentLoadingMessageCell)
}

protocol AttachmentLoadingMessageCell: class {
    var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate? { get set }
    func updateProgress(viewModel: AttachmentLoadingViewModel)
}

protocol AttachmentExpirationHintingMessageCell: AttachmentLoadingMessageCell {
    var operationButton: NetworkOperationButton { get }
    var expiredHintLabel: UILabel { get }
}

extension AttachmentExpirationHintingMessageCell where Self: PhotoRepresentableMessageCell {
    
    func prepareOperationButtonAndExpiredHintLabel() {
        operationButton.style = .finished(showPlayIcon: false)
        operationButton.bounds.size = CGSize(width: 60, height: 60)
        contentView.addSubview(operationButton)
        expiredHintLabel.text = Localized.CHAT_FILE_EXPIRED
        expiredHintLabel.textColor = UIColor(rgbValue: 0xEFEFF4)
        expiredHintLabel.font = .systemFont(ofSize: 13)
        expiredHintLabel.sizeToFit()
        expiredHintLabel.isHidden = true
        contentView.addSubview(expiredHintLabel)
    }
    
    func renderOperationButtonAndExpiredHintLabel(viewModel: PhotoRepresentableMessageViewModel) {
        operationButton.center = CGPoint(x: viewModel.contentFrame.midX, y: viewModel.contentFrame.midY)
        if let viewModel = viewModel as? AttachmentLoadingViewModel {
            operationButton.style = viewModel.operationButtonStyle
            if viewModel.mediaStatus == MediaStatus.EXPIRED.rawValue {
                expiredHintLabel.isHidden = false
                operationButton.center.y -= expiredHintLabel.frame.height
                expiredHintLabel.center.x = operationButton.center.x
                expiredHintLabel.frame.origin.y = operationButton.frame.maxY
            } else {
                expiredHintLabel.isHidden = true
            }
        }
    }
    
}
