import UIKit
import SDWebImage

class PhotoRepresentableMessageCell: ImageMessageCell {
    
    let contentImageWrapperView = VerticalPositioningImageView()
    let expandImageView = UIImageView(image: R.image.conversation.ic_message_expand())
    
    var contentImageView: UIImageView {
        return contentImageWrapperView.imageView
    }
    
    override var contentFrame: CGRect {
        if viewModel?.quotedMessageViewModel == nil {
            return contentImageWrapperView.convert(contentImageWrapperView.bounds, to: self)
        } else {
            return backgroundImageView.frame
        }
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoRepresentableMessageViewModel {
            if viewModel.quotedMessageViewModel == nil {
                maskingView.frame = messageContentView.bounds
                contentImageWrapperView.frame = viewModel.photoFrame
                maskingView.layer.cornerRadius = 0
                if backgroundImageView.superview != nil {
                    backgroundImageView.removeFromSuperview()
                }
                if maskingView.layer.mask == nil {
                    maskingView.layer.mask = backgroundImageView.layer
                }
            } else {
                maskingView.frame = viewModel.photoFrame
                contentImageWrapperView.frame = maskingView.bounds
                if maskingView.layer.mask == backgroundImageView.layer {
                    maskingView.layer.mask = nil
                }
                if backgroundImageView.superview == nil {
                    messageContentView.insertSubview(backgroundImageView, at: 0)
                }
                maskingView.layer.cornerRadius = Self.quotingPhotoCornerRadius
            }
            selectedOverlapView.frame = contentImageWrapperView.bounds
            contentImageWrapperView.position = viewModel.layoutPosition
            contentImageWrapperView.aspectRatio = viewModel.contentRatio
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
            if let origin = viewModel.expandIconOrigin {
                expandImageView.isHidden = false
                expandImageView.frame.origin = origin
            } else {
                expandImageView.isHidden = true
            }
        }
    }
    
    override func prepare() {
        messageContentView.addSubview(maskingView)
        maskingView.addSubview(contentImageWrapperView)
        updateAppearance(highlight: false, animated: false)
        contentImageWrapperView.addSubview(selectedOverlapView)
        messageContentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        expandImageView.isHidden = true
        messageContentView.addSubview(expandImageView)
        maskingView.clipsToBounds = true
        forwarderImageView.alpha = 0.9
        encryptedImageView.alpha = 0.9
        pinnedImageView.alpha = 0.9
        statusImageView.alpha = 0.9
    }
    
    func reloadMedia(viewModel: PhotoRepresentableMessageViewModel) {
        
    }
    
}

extension PhotoRepresentableMessageCell: GalleryTransitionSource {
    
    var imageWrapperView: VerticalPositioningImageView! {
        return contentImageWrapperView
    }
    
    var transitionViewType: GalleryTransitionView.Type {
        if viewModel?.quotedMessageViewModel == nil {
            return GalleryTransitionFromNonQuotingMessageCellView.self
        } else {
            return GalleryTransitionFromQuotingMessageCellView.self
        }
    }
    
    var direction: GalleryItemModelController.Direction {
        return .forward
    }
    
}
