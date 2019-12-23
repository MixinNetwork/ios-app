import UIKit
import SDWebImage
import MixinServices

class PhotoMessageCell: PhotoRepresentableMessageCell, AttachmentExpirationHintingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let operationButton: NetworkOperationButton! = ModernNetworkOperationButton(type: .custom)
    let expiredHintLabel = UILabel()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.sd_cancelCurrentImageLoad()
    }
    
    override func prepare() {
        super.prepare()
        expiredHintLabel.adjustsFontForContentSizeCategory = true
        prepareOperationButtonAndExpiredHintLabel()
        operationButton.addTarget(self, action: #selector(networkOperationAction(_:)), for: .touchUpInside)
    }
    
    override func reloadMedia(viewModel: PhotoRepresentableMessageViewModel) {
        if let mediaUrl = viewModel.message.mediaUrl, !mediaUrl.isEmpty, !mediaUrl.hasPrefix("http") {
            let url = AttachmentContainer.url(for: .photos, filename: mediaUrl)
            contentImageView.sd_setImage(with: url, placeholderImage: viewModel.thumbnail, context: localImageContext)
        } else {
            contentImageView.image = viewModel.thumbnail
        }
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoMessageViewModel {
            reloadMedia(viewModel: viewModel)
            updateOperationButtonAndExpiredHintLabel()
        }
    }
    
    @objc func networkOperationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
}
