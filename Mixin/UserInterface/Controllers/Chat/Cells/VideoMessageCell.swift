import UIKit
import MixinServices

class VideoMessageCell: PhotoRepresentableMessageCell, AttachmentExpirationHintingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let operationButton: NetworkOperationButton! = ModernNetworkOperationButton(type: .custom)
    let expiredHintLabel = UILabel()
    let lengthLabel = InsetLabel()
    
    override func prepare() {
        super.prepare()
        prepareOperationButtonAndExpiredHintLabel()
        operationButton.addTarget(self, action: #selector(networkOperationAction(_:)), for: .touchUpInside)
        lengthLabel.layer.backgroundColor = UIColor.black.withAlphaComponent(0.4).cgColor
        lengthLabel.textColor = .white
        lengthLabel.font = .preferredFont(forTextStyle: .caption1)
        lengthLabel.adjustsFontForContentSizeCategory = true
        lengthLabel.numberOfLines = 1
        lengthLabel.layer.cornerRadius = 4
        lengthLabel.clipsToBounds = true
        lengthLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        contentView.addSubview(lengthLabel)
    }
    
    override func reloadMedia(viewModel: PhotoRepresentableMessageViewModel) {
        contentImageWrapperView.aspectRatio = viewModel.contentRatio
        contentImageView.image = viewModel.thumbnail
        if let viewModel = viewModel as? VideoMessageViewModel, viewModel.duration != nil || viewModel.fileSize != nil {
            let mediaHasDownloaded = viewModel.message.mediaStatus == MediaStatus.DONE.rawValue
                || viewModel.message.mediaStatus == MediaStatus.READ.rawValue
            let length = mediaHasDownloaded
                ? (viewModel.duration ?? viewModel.fileSize)
                : (viewModel.fileSize ?? viewModel.duration)
            lengthLabel.text = length
            lengthLabel.sizeToFit()
            lengthLabel.frame.origin = viewModel.durationLabelOrigin
            lengthLabel.isHidden = false
        } else {
            lengthLabel.isHidden = true
        }
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? VideoMessageViewModel {
            updateOperationButtonAndExpiredHintLabel()
            reloadMedia(viewModel: viewModel)
        }
    }
    
    @objc func networkOperationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
}

