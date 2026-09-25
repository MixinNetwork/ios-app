import UIKit
import SDWebImage
import MixinServices

class PhotoMessageCell: PhotoRepresentableMessageCell, AttachmentExpirationHintingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let operationButton: NetworkOperationButton! = ModernNetworkOperationButton(type: .custom)
    let expiredHintLabel = UILabel()
    let captionLabel = TextMessageLabel()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.sd_cancelCurrentImageLoad()
        captionLabel.isHidden = true
    }
    
    override func prepare() {
        super.prepare()
        expiredHintLabel.adjustsFontForContentSizeCategory = true
        prepareOperationButtonAndExpiredHintLabel()
        operationButton.addTarget(self, action: #selector(networkOperationAction(_:)), for: .touchUpInside)
        captionLabel.backgroundColor = .clear
        messageContentView.addSubview(captionLabel)
    }
    
    override func reloadMedia(viewModel: PhotoRepresentableMessageViewModel) {
        if let url = (viewModel as? PhotoMessageViewModel)?.attachmentURL {
            contentImageView.sd_setImage(with: url,
                                         placeholderImage: viewModel.thumbnail,
                                         context: localImageContext)
        } else {
            contentImageView.image = viewModel.thumbnail
        }
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoMessageViewModel {
            reloadMedia(viewModel: viewModel)
            updateOperationButtonAndExpiredHintLabel()
            if viewModel.hasCaption {
                captionLabel.frame = viewModel.captionLabelFrame
                captionLabel.content = viewModel.captionContent
                captionLabel.highlightPaths = viewModel.highlightPaths
                captionLabel.isHidden = false
                captionLabel.setNeedsDisplay()
                trailingInfoBackgroundView.isHidden = true
            } else {
                captionLabel.isHidden = true
                trailingInfoBackgroundView.isHidden = false
            }
        }
    }
    
    @objc func networkOperationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
}
