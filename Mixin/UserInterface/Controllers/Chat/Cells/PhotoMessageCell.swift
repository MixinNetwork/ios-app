import UIKit
import SDWebImage
import FLAnimatedImage

class PhotoMessageCell: DetailInfoMessageCell, AttachmentLoadingMessageCell {
    
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate?
    
    let contentImageView = FLAnimatedImageView()
    let shadowImageView = UIImageView()
    let operationButton: NetworkOperationButton! = NetworkOperationButton(type: .custom)
    
    private let expiredHintLabel = UILabel()

    override var contentFrame: CGRect {
        return contentImageView.frame
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.sd_cancelCurrentImageLoad()
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoMessageViewModel {
            contentImageView.frame = viewModel.contentFrame
            contentImageView.layer.mask = backgroundImageView.layer
            operationButton.center = CGPoint(x: viewModel.contentFrame.midX, y: viewModel.contentFrame.midY)
            operationButton.style = viewModel.operationButtonStyle
            if viewModel.mediaStatus == MediaStatus.EXPIRED.rawValue {
                expiredHintLabel.isHidden = false
                operationButton.center.y -= expiredHintLabel.frame.height
                expiredHintLabel.center.x = operationButton.center.x
                expiredHintLabel.frame.origin.y = operationButton.frame.maxY
            } else {
                expiredHintLabel.isHidden = true
            }
            shadowImageView.image = viewModel.shadowImage
            shadowImageView.frame = CGRect(origin: viewModel.shadowImageOrigin,
                                           size: viewModel.shadowImage?.size ?? .zero)
            let message = viewModel.message
            if let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty {
                contentImageView.sd_setImage(with: MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl))
            } else if let thumbImage = message.thumbImage {
                if let imageData = Data(base64Encoded: thumbImage) {
                    contentImageView.image = UIImage(data: imageData)
                }
            }
        }
    }
    
    override func prepare() {
        contentView.addSubview(contentImageView)
        contentImageView.contentMode = .scaleAspectFill
        contentImageView.clipsToBounds = true
        contentImageView.layer.cornerRadius = 6
        timeLabel.textColor = .white
        shadowImageView.contentMode = .scaleToFill
        shadowImageView.layer.cornerRadius = 6
        shadowImageView.clipsToBounds = true
        contentView.addSubview(shadowImageView)
        operationButton.style = .finished(showPlayIcon: false)
        operationButton.bounds.size = CGSize(width: 60, height: 60)
        operationButton.addTarget(self, action: #selector(networkOperationAction(_:)), for: .touchUpInside)
        contentView.addSubview(operationButton)
        expiredHintLabel.text = Localized.CHAT_FILE_EXPIRED
        expiredHintLabel.textColor = UIColor(rgbValue: 0xEFEFF4)
        expiredHintLabel.font = .systemFont(ofSize: 13)
        expiredHintLabel.sizeToFit()
        expiredHintLabel.isHidden = true
        contentView.addSubview(expiredHintLabel)
        super.prepare()
        backgroundImageView.removeFromSuperview()
    }
    
    @objc func networkOperationAction(_ sender: Any) {
        attachmentLoadingDelegate?.attachmentLoadingCellDidSelectNetworkOperation(self)
    }
    
    func updateProgress(viewModel: AttachmentLoadingViewModel) {
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
    }

    func contentSnapshotView(afterScreenUpdates: Bool) -> UIView {
        let view = UIImageView(frame: contentFrame)
        view.contentMode = .scaleAspectFit
        UIGraphicsBeginImageContextWithOptions(contentFrame.size, false, UIScreen.main.scale)
        contentImageView.drawHierarchy(in: view.bounds, afterScreenUpdates: afterScreenUpdates)
        let shadowRect = shadowImageView.convert(shadowImageView.bounds, to: contentImageView)
        shadowImageView.drawHierarchy(in: shadowRect, afterScreenUpdates: afterScreenUpdates)
        let timeRect = timeLabel.convert(timeLabel.bounds, to: contentImageView)
        timeLabel.drawHierarchy(in: timeRect, afterScreenUpdates: afterScreenUpdates)
        let statusRect = statusImageView.convert(statusImageView.bounds, to: contentImageView)
        statusImageView.drawHierarchy(in: statusRect, afterScreenUpdates: afterScreenUpdates)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        view.image = image
        return view
    }
    
}
