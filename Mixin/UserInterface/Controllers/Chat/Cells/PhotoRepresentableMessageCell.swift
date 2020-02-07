import UIKit
import SDWebImage
import YYImage

class PhotoRepresentableMessageCell: DetailInfoMessageCell {
    
    static let quotingPhotoCornerRadius: CGFloat = 6
    
    let maskingView = UIView()
    let contentImageWrapperView = VerticalPositioningImageView()
    let trailingInfoBackgroundView = TrailingInfoBackgroundView()
    
    var contentImageView: UIImageView {
        return contentImageWrapperView.imageView
    }
    
    lazy var selectedOverlapView: UIView = {
        let view = SelectedOverlapView()
        view.alpha = 0
        contentView.addSubview(view)
        return view
    }()
    
    override var contentFrame: CGRect {
        if quotedMessageViewIfLoaded == nil {
            return contentImageWrapperView.convert(contentImageWrapperView.bounds, to: self)
        } else {
            return backgroundImageView.frame
        }
    }
    
    override var trailingInfoColor: UIColor {
        .white
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoRepresentableMessageViewModel {
            if viewModel.quotedMessageViewModel == nil {
                maskingView.frame = contentView.bounds
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
                    contentView.insertSubview(backgroundImageView, at: 0)
                }
                maskingView.layer.cornerRadius = Self.quotingPhotoCornerRadius
            }
            selectedOverlapView.frame = contentImageWrapperView.bounds
            contentImageWrapperView.position = viewModel.layoutPosition
            contentImageWrapperView.aspectRatio = viewModel.contentRatio
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
        }
    }
    
    override func prepare() {
        contentView.addSubview(maskingView)
        maskingView.addSubview(contentImageWrapperView)
        updateAppearance(highlight: false, animated: false)
        contentImageWrapperView.addSubview(selectedOverlapView)
        contentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        maskingView.clipsToBounds = true
        encryptedImageView.alpha = 0.9
        statusImageView.alpha = 0.9
    }
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        UIView.animate(withDuration: animated ? highlightAnimationDuration : 0) {
            self.selectedOverlapView.alpha = highlight ? 1 : 0
        }
        if quotedMessageViewIfLoaded != nil {
            super.updateAppearance(highlight: highlight, animated: animated)
        }
    }
    
    func reloadMedia(viewModel: PhotoRepresentableMessageViewModel) {
        
    }
    
}

extension PhotoRepresentableMessageCell: GalleryTransitionSource {
    
    var imageWrapperView: VerticalPositioningImageView! {
        return contentImageWrapperView
    }
    
    var transitionViewType: GalleryTransitionView.Type {
        if quotedMessageViewIfLoaded == nil {
            return GalleryTransitionFromNonQuotingMessageCellView.self
        } else {
            return GalleryTransitionFromQuotingMessageCellView.self
        }
    }
    
    var direction: GalleryItemModelController.Direction {
        return .forward
    }
    
}

extension PhotoRepresentableMessageCell {
    
    class SelectedOverlapView: UIView {
        
        override var backgroundColor: UIColor? {
            set {
                
            }
            get {
                return super.backgroundColor
            }
        }
        
        private let dimmingColor = UIColor.black.withAlphaComponent(0.2)
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            super.backgroundColor = dimmingColor
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            super.backgroundColor = dimmingColor
        }
        
    }
    
}

