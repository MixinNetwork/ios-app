import UIKit

class VideoMessageCell: PhotoRepresentableMessageCell, AttachmentExpirationHintingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let operationButton = NetworkOperationButton(type: .custom)
    let expiredHintLabel = UILabel()
    let durationLabel = InsetLabel()
    
    override lazy var contentSnapshotViews = [
        contentImageView,
        shadowImageView,
        timeLabel,
        statusImageView,
        durationLabel
    ]
    
    override func prepare() {
        super.prepare()
        prepareOperationButtonAndExpiredHintLabel()
        operationButton.addTarget(self, action: #selector(networkOperationAction(_:)), for: .touchUpInside)
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        durationLabel.textColor = .white
        durationLabel.font = .systemFont(ofSize: 12)
        durationLabel.numberOfLines = 1
        durationLabel.layer.cornerRadius = 4
        durationLabel.clipsToBounds = true
        durationLabel.contentInset = UIEdgeInsetsMake(1, 4, 1, 4)
        addSubview(durationLabel)
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? VideoMessageViewModel {
            renderOperationButtonAndExpiredHintLabel(viewModel: viewModel)
            contentImageView.image = viewModel.betterThumbnail ?? viewModel.thumbnail
            if let duration = viewModel.duration {
                durationLabel.text = duration
                durationLabel.sizeToFit()
                durationLabel.frame.origin = contentImageView.frame.origin + CGPoint(x: 9, y: 8)
                durationLabel.isHidden = false
            } else {
                durationLabel.isHidden = true
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

