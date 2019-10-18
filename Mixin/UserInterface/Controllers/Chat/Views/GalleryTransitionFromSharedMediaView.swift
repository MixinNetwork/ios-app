import UIKit

class GalleryTransitionFromSharedMediaView: GalleryTransitionView {
    
    override func load(source: GalleryTransitionSource) {
        guard let cell = source as? SharedMediaCell else {
            return
        }
        contentSize = cell.item?.size ?? cell.imageView.image?.size
        frame = cell.contentView.convert(cell.imageWrapperView.frame, to: superview)
        imageView.image = cell.imageView.image
        imageWrapperView.imageView.contentMode = cell.imageWrapperView.contentMode
        imageWrapperView.aspectRatio = cell.imageWrapperView.aspectRatio
        imageWrapperView.position = cell.imageWrapperView.position
        imageWrapperView.frame = bounds
        imageWrapperView.layoutIfNeeded()
    }
    
    override func transition(to containerView: UIView) {
        let containerBounds = containerView.bounds
        
        let size: CGSize
        if let contentSize = contentSize {
            size = contentSize
        } else if let image = imageView.image {
            let imageRatio = image.size.width / image.size.height
            let imageWrapperRatio = imageWrapperView.frame.width / imageWrapperView.frame.height
            if imageRatio < imageWrapperRatio {
                size = image.size
            } else {
                size = imageWrapperView.frame.size
            }
        } else {
            size = imageWrapperView.frame.size
        }
        
        let frame: CGRect
        if GalleryItem.shouldLayoutImageOfRatioAsAriticle(size) {
            let height = min(containerBounds.height, containerBounds.width / size.width * size.height)
            let size = CGSize(width: containerBounds.width, height: height)
            let origin = CGPoint(x: 0, y: (containerBounds.height - height) / 2)
            frame = CGRect(origin: origin, size: size)
        } else {
            frame = size.rect(fittingSize: containerBounds.size)
        }
        
        animate(animations: {
            self.frame = frame
            self.imageWrapperView.frame = self.bounds
        })
    }
    
    override func transition(to source: GalleryTransitionSource) {
        guard let cell = source as? SharedMediaCell else {
            return
        }
        imageWrapperView.imageView.contentMode = cell.imageWrapperView.contentMode
        
        let frame = cell.contentView.convert(cell.imageWrapperView.frame, to: superview)
        let bounds = CGRect(origin: .zero, size: frame.size)
        
        animate(animations: {
            self.transform = .identity
            self.frame = frame
            self.imageWrapperView.frame = bounds
        })
    }
    
    override func prepare() {
        super.prepare()
        imageWrapperView.backgroundColor = .clear
        imageView.autoPlayAnimatedImage = false
    }
    
}
