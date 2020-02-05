import UIKit
import SDWebImage
import YYImage

class PhotoRepresentableMessageCell: DetailInfoMessageCell {
    
    let maskingContentView = UIView()
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
        return contentImageWrapperView.frame
    }
    
    override var trailingInfoColor: UIColor {
        .white
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoRepresentableMessageViewModel {
            contentImageWrapperView.position = viewModel.layoutPosition
            contentImageWrapperView.frame = viewModel.presentationFrame
            contentImageWrapperView.aspectRatio = viewModel.contentRatio
            selectedOverlapView.frame = contentImageWrapperView.bounds
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
        }
    }
    
    override func prepare() {
        contentView.addSubview(maskingContentView)
        maskingContentView.frame = contentView.bounds
        maskingContentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        maskingContentView.addSubview(contentImageWrapperView)
        updateAppearance(highlight: false, animated: false)
        contentImageWrapperView.addSubview(selectedOverlapView)
        contentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        backgroundImageView.removeFromSuperview()
        maskingContentView.layer.masksToBounds = true
        maskingContentView.layer.mask = backgroundImageView.layer
        encryptedImageView.alpha = 0.9
        statusImageView.alpha = 0.9
    }
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        UIView.animate(withDuration: animated ? highlightAnimationDuration : 0) {
            self.selectedOverlapView.alpha = highlight ? 1 : 0
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
        return GalleryTransitionFromMessageCellView.self
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

