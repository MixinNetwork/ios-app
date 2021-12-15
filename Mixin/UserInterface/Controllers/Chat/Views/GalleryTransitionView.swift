import UIKit
import SDWebImage

protocol GalleryTransitionSource: UIView {
    var imageWrapperView: VerticalPositioningImageView! { get }
    var transitionViewType: GalleryTransitionView.Type { get }
    var direction: GalleryItemModelController.Direction { get }
}

class GalleryTransitionView: UIView, GalleryAnimatable {
    
    let imageWrapperView = VerticalPositioningImageView()
    
    var contentRatio: CGSize?
    
    var imageView: SDAnimatedImageView {
        return imageWrapperView.imageView
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    func load(source: GalleryTransitionSource) {
        
    }
    
    func transition(to containerView: UIView) {
        
    }
    
    func load(viewController: GalleryItemViewController) {
        guard let item = viewController.item, let superview = superview else {
            return
        }
        imageWrapperView.aspectRatio = item.size
        imageView.image = viewController.image
        if let controller = viewController as? GalleryImageItemViewController {
            var size = controller.imageView.bounds.size
            size.height = min(size.height, superview.bounds.height)
            bounds.size = size
            center = CGPoint(x: superview.bounds.midX, y: superview.bounds.midY)
            imageWrapperView.frame = bounds
            if item.shouldLayoutAsArticle, let relativeOffset = (viewController as? GalleryImageItemViewController)?.relativeOffset {
                imageWrapperView.position = .relativeOffset(relativeOffset)
            } else {
                imageWrapperView.position = .center
            }
            
            let scrollView = controller.scrollView
            var transform = CGAffineTransform.identity
            if scrollView.zoomScale != 1 {
                let scale = CGAffineTransform(scaleX: scrollView.zoomScale, y: scrollView.zoomScale)
                transform = transform.concatenating(scale)
            }
            if !item.shouldLayoutAsArticle {
                let x = scrollView.contentSize.width > scrollView.frame.width
                    ? scrollView.contentOffset.x + viewController.view.bounds.width / 2 - bounds.width * scrollView.zoomScale / 2
                    : 0
                let y = scrollView.contentSize.height > scrollView.frame.height
                    ? scrollView.contentOffset.y + viewController.view.bounds.height / 2 - bounds.height * scrollView.zoomScale / 2
                    : 0
                let offset = CGAffineTransform(translationX: -x, y: -y)
                transform = transform.concatenating(offset)
            }
            self.transform = transform
        } else if let controller = viewController as? GalleryVideoItemViewController {
            frame = controller.videoView.contentView.frame
            let wrapperWidth = bounds.height / item.size.height * item.size.width
            imageWrapperView.bounds.size = CGSize(width: wrapperWidth, height: bounds.height)
            imageWrapperView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            imageWrapperView.position = .center
        } else {
            frame = viewController.view.bounds
            imageWrapperView.frame = bounds
            imageWrapperView.position = .center
        }
        imageWrapperView.layoutIfNeeded()
    }
    
    func transition(to source: GalleryTransitionSource) {
        
    }
    
    func prepare() {
        imageWrapperView.backgroundColor = .black
        addSubview(imageWrapperView)
    }
    
}
