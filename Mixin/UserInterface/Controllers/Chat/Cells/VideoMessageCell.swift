import UIKit

class VideoMessageCell: PhotoRepresentableMessageCell, AttachmentExpirationHintingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let operationButton: NetworkOperationButton! = NetworkOperationButton(type: .custom)
    let expiredHintLabel = UILabel()
    let lengthLabel = InsetLabel()
    
    override func prepare() {
        super.prepare()
        prepareOperationButtonAndExpiredHintLabel()
        operationButton.addTarget(self, action: #selector(networkOperationAction(_:)), for: .touchUpInside)
        lengthLabel.layer.backgroundColor = UIColor.black.withAlphaComponent(0.4).cgColor
        lengthLabel.textColor = .white
        lengthLabel.font = .systemFont(ofSize: 12)
        lengthLabel.numberOfLines = 1
        lengthLabel.layer.cornerRadius = 4
        lengthLabel.clipsToBounds = true
        lengthLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        addSubview(lengthLabel)
    }
    
    override func reloadImage(viewModel: PhotoRepresentableMessageViewModel) {
        contentImageView.image = viewModel.thumbnail
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? VideoMessageViewModel {
            updateOperationButtonAndExpiredHintLabel()
            reloadImage(viewModel: viewModel)
            if viewModel.duration != nil || viewModel.fileSize != nil {
                lengthLabel.text = viewModel.duration ?? viewModel.fileSize
                lengthLabel.sizeToFit()
                lengthLabel.frame.origin = viewModel.durationLabelOrigin
                lengthLabel.isHidden = false
            } else {
                lengthLabel.isHidden = true
            }
        }
    }
    
    @objc func networkOperationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
}

