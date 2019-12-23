import UIKit
import MixinServices

protocol AttachmentExpirationHintingMessageCell: AttachmentLoadingMessageCell {
    var expiredHintLabel: UILabel { get }
}

extension AttachmentExpirationHintingMessageCell where Self: PhotoRepresentableMessageCell {
    
    func prepareOperationButtonAndExpiredHintLabel() {
        operationButton.style = .finished(showPlayIcon: false)
        operationButton.bounds.size = CGSize(width: 60, height: 60)
        contentView.addSubview(operationButton)
        expiredHintLabel.text = Localized.CHAT_FILE_EXPIRED
        expiredHintLabel.textColor = UIColor(rgbValue: 0xEFEFF4)
        expiredHintLabel.font = .preferredFont(forTextStyle: .footnote)
        expiredHintLabel.adjustsFontForContentSizeCategory = true
        expiredHintLabel.sizeToFit()
        expiredHintLabel.isHidden = true
        contentView.addSubview(expiredHintLabel)
    }
    
    func updateOperationButtonAndExpiredHintLabel() {
        guard let viewModel = viewModel as? PhotoRepresentableMessageViewModel else {
            return
        }
        operationButton.center = CGPoint(x: viewModel.contentFrame.midX, y: viewModel.contentFrame.midY)
        if let viewModel = viewModel as? AttachmentLoadingViewModel {
            updateOperationButtonStyle()
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
