import UIKit

class VideoMessageCell: PhotoRepresentableMessageCell, AttachmentExpirationHintingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let operationButton = NetworkOperationButton(type: .custom)
    let expiredHintLabel = UILabel()
    let lengthLabel = InsetLabel()
    
    override lazy var contentSnapshotViews = [
        contentImageView,
        shadowImageView,
        timeLabel,
        statusImageView,
        lengthLabel
    ]
    
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
        lengthLabel.contentInset = UIEdgeInsetsMake(1, 4, 1, 4)
        addSubview(lengthLabel)
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? VideoMessageViewModel {
            renderOperationButtonAndExpiredHintLabel(viewModel: viewModel)
            contentImageView.image = viewModel.betterThumbnail ?? viewModel.thumbnail
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
    
    func updateProgress(viewModel: AttachmentLoadingViewModel) {
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
    }
    
}

