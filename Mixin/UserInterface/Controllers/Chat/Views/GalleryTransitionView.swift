import UIKit

final class GalleryTransitionView: UIView, GalleryAnimatable {
    
    private let imageView = VerticalPositioningImageView()
    private let accessoryContainerView = UIView()
    private let shadowImageView = UIImageView(image: PhotoRepresentableMessageViewModel.shadowImage)
    private let timeLabel = UILabel()
    private let statusImageView = UIImageView()
    private let maskLayer = BubbleLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    func load(cell: PhotoRepresentableMessageCell) {
        guard let viewModel = cell.viewModel as? PhotoRepresentableMessageViewModel else {
            return
        }
        frame = cell.contentView.convert(cell.contentImageView.frame, to: superview)
        imageView.position = cell.contentImageView.position
        imageView.image = cell.contentImageView.image
        imageView.frame = bounds
        imageView.layoutIfNeeded()
        accessoryContainerView.transform = .identity
        accessoryContainerView.alpha = 1
        accessoryContainerView.frame = bounds
        shadowImageView.frame.origin = cell.contentView.convert(viewModel.shadowImageOrigin, to: cell.contentImageView)
        timeLabel.text = viewModel.time
        timeLabel.frame = cell.contentView.convert(viewModel.timeFrame, to: cell.contentImageView)
        statusImageView.image = viewModel.statusImage
        statusImageView.tintColor = viewModel.statusTintColor
        statusImageView.frame = cell.contentView.convert(viewModel.statusFrame, to: cell.contentImageView)
        let bubble = BubbleLayer.Bubble(style: viewModel.style)
        maskLayer.setBubble(bubble, frame: bounds, animationDuration: 0)
        maskLayer.bounds.size = imageView.bounds.size
        maskLayer.position = CGPoint(x: imageView.bounds.midX, y: imageView.bounds.midY)
    }
    
    func transition(to containerView: UIView) {
        let containerBounds = containerView.bounds
        let scale = containerBounds.width / bounds.width
        let ratio: CGFloat
        if let image = imageView.image {
            ratio = image.size.width / image.size.height
        } else {
            ratio = imageView.frame.width / imageView.frame.height
        }
        let height = min(containerBounds.height, containerBounds.width / ratio)
        let size = CGSize(width: containerBounds.width, height: height)
        let origin = CGPoint(x: 0, y: (containerBounds.height - height) / 2)
        let frame = CGRect(origin: origin, size: size)
        let bounds = CGRect(origin: .zero, size: size)
        maskLayer.setBubble(.none, frame: bounds, animationDuration: animationDuration)
        animate(animations: {
            self.frame = frame
            self.imageView.frame = self.bounds
            self.accessoryContainerView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            self.accessoryContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.accessoryContainerView.alpha = 0
        }) 
    }
    
    func load(viewController: GalleryItemViewController) {
        guard let item = viewController.item, let superview = superview else {
            return
        }
        imageView.image = viewController.image
        if let controller = viewController as? GalleryImageItemViewController {
            var size = controller.imageView.bounds.size
            size.height = min(size.height, superview.bounds.height)
            bounds.size = size
            center = CGPoint(x: superview.bounds.midX, y: superview.bounds.midY)
            imageView.frame = bounds
            if item.shouldLayoutAsArticle, let relativeOffset = (viewController as? GalleryImageItemViewController)?.relativeOffset {
                imageView.position = .relativeOffset(relativeOffset)
            } else {
                imageView.position = .center
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
        } else {
            frame = viewController.view.bounds
            imageView.frame = bounds
            imageView.position = .center
        }
        imageView.layoutIfNeeded()
        maskLayer.setBubble(.none, frame: bounds, animationDuration: 0)
        maskLayer.frame = bounds
    }
    
    func transition(to cell: PhotoRepresentableMessageCell) {
        guard let viewModel = cell.viewModel as? PhotoRepresentableMessageViewModel else {
            return
        }
        let scale = bounds.width / cell.contentImageView.frame.width
        accessoryContainerView.transform = .identity
        accessoryContainerView.bounds.size = cell.contentImageView.bounds.size
        shadowImageView.frame.origin = cell.contentView.convert(viewModel.shadowImageOrigin, to: cell.contentImageView)
        timeLabel.text = viewModel.time
        timeLabel.frame = cell.contentView.convert(viewModel.timeFrame, to: cell.contentImageView)
        statusImageView.image = viewModel.statusImage
        statusImageView.tintColor = viewModel.statusTintColor
        statusImageView.frame = cell.contentView.convert(viewModel.statusFrame, to: cell.contentImageView)
        
        accessoryContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        accessoryContainerView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        accessoryContainerView.alpha = 0
        
        let frame = cell.contentView.convert(cell.contentImageView.frame, to: superview)
        let bounds = CGRect(origin: .zero, size: frame.size)

        let bubble = BubbleLayer.Bubble(style: viewModel.style)
        maskLayer.setBubble(bubble, frame: bounds, animationDuration: animationDuration)
        
        animate(animations: {
            self.transform = .identity
            self.frame = frame
            self.imageView.frame = bounds
            self.accessoryContainerView.transform = .identity
            self.accessoryContainerView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            self.accessoryContainerView.alpha = 1
        }, completion: {
        })
    }
    
    private func prepare() {
        accessoryContainerView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFill
        timeLabel.backgroundColor = .clear
        timeLabel.font = DetailInfoMessageViewModel.timeFont
        timeLabel.textAlignment = .right
        timeLabel.textColor = .white
        statusImageView.contentMode = .left
        shadowImageView.frame.size = shadowImageView.image?.size ?? .zero
        addSubview(imageView)
        accessoryContainerView.addSubview(shadowImageView)
        accessoryContainerView.addSubview(timeLabel)
        accessoryContainerView.addSubview(statusImageView)
        addSubview(accessoryContainerView)
        layer.mask = maskLayer
    }
    
}
