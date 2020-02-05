import UIKit

class GalleryTransitionFromMessageCellView: GalleryTransitionView {
    
    private let accessoryContainerView = UIView()
    private let timeLabel = UILabel()
    private let statusImageView = UIImageView()
    private let maskLayer = BubbleLayer()
    
    override func load(viewController: GalleryItemViewController) {
        super.load(viewController: viewController)
        maskLayer.setBubble(.none, frame: bounds, animationDuration: 0)
        maskLayer.frame = bounds
    }
    
    override func load(source: GalleryTransitionSource) {
        guard let cell = source as? PhotoRepresentableMessageCell else {
            return
        }
        guard let viewModel = cell.viewModel as? PhotoRepresentableMessageViewModel else {
            return
        }
        contentRatio = viewModel.contentRatio
        frame = cell.contentView.convert(cell.contentImageWrapperView.frame, to: superview)
        imageView.image = cell.contentImageView.image
        imageWrapperView.imageView.contentMode = cell.contentImageView.contentMode
        imageWrapperView.aspectRatio = cell.contentImageWrapperView.aspectRatio
        imageWrapperView.position = cell.contentImageWrapperView.position
        imageWrapperView.frame = bounds
        imageWrapperView.layoutIfNeeded()
        accessoryContainerView.transform = .identity
        accessoryContainerView.alpha = 1
        accessoryContainerView.frame = bounds
        timeLabel.text = viewModel.time
        timeLabel.frame = cell.contentView.convert(viewModel.timeFrame, to: cell.contentImageWrapperView)
        statusImageView.image = viewModel.statusImage
        statusImageView.tintColor = viewModel.statusTintColor
        statusImageView.frame = cell.contentView.convert(viewModel.statusFrame, to: cell.contentImageWrapperView)
        let bubble = BubbleLayer.Bubble(style: viewModel.style)
        maskLayer.setBubble(bubble, frame: bounds, animationDuration: 0)
        maskLayer.bounds.size = imageWrapperView.bounds.size
        maskLayer.position = CGPoint(x: imageWrapperView.bounds.midX, y: imageWrapperView.bounds.midY)
    }
    
    override func transition(to containerView: UIView) {
        let containerBounds = containerView.bounds
        let scale = containerBounds.width / bounds.width
        let frame: CGRect
        let bubbleFrame: CGRect
        
        let ratio: CGSize
        if let contentRatio = contentRatio {
            ratio = contentRatio
        } else if let image = imageView.image {
            let imageRatio = image.size.width / image.size.height
            let imageWrapperRatio = imageWrapperView.frame.width / imageWrapperView.frame.height
            if imageRatio < imageWrapperRatio {
                ratio = image.size
            } else {
                ratio = imageWrapperView.frame.size
            }
        } else {
            ratio = imageWrapperView.frame.size
        }
        
        if GalleryItem.shouldLayoutImageOfRatioAsAriticle(ratio) {
            let height = min(containerBounds.height, containerBounds.width / ratio.width * ratio.height)
            let size = CGSize(width: containerBounds.width, height: height)
            let origin = CGPoint(x: 0, y: (containerBounds.height - height) / 2)
            frame = CGRect(origin: origin, size: size)
            bubbleFrame = CGRect(origin: .zero, size: size)
        } else {
            frame = ratio.rect(fittingSize: containerBounds.size)
            bubbleFrame = containerBounds
        }
        
        maskLayer.setBubble(.none, frame: bubbleFrame, animationDuration: animationDuration)
        animate(animations: {
            self.frame = frame
            self.imageWrapperView.frame = self.bounds
            self.accessoryContainerView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            self.accessoryContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.accessoryContainerView.alpha = 0
        })
    }
    
    override func transition(to source: GalleryTransitionSource) {
        guard let cell = source as? PhotoRepresentableMessageCell else {
            return
        }
        imageWrapperView.imageView.contentMode = cell.contentImageView.contentMode
        guard let viewModel = cell.viewModel as? PhotoRepresentableMessageViewModel else {
            return
        }
        let scale = bounds.width / cell.contentImageWrapperView.frame.width
        accessoryContainerView.transform = .identity
        accessoryContainerView.bounds.size = cell.contentImageWrapperView.bounds.size
        timeLabel.text = viewModel.time
        timeLabel.frame = cell.contentView.convert(viewModel.timeFrame, to: cell.contentImageWrapperView)
        statusImageView.image = viewModel.statusImage
        statusImageView.tintColor = viewModel.statusTintColor
        statusImageView.frame = cell.contentView.convert(viewModel.statusFrame, to: cell.contentImageWrapperView)
        
        accessoryContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        accessoryContainerView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        accessoryContainerView.alpha = 0
        
        let frame = cell.contentView.convert(cell.contentImageWrapperView.frame, to: superview)
        let bounds = CGRect(origin: .zero, size: frame.size)

        let bubble = BubbleLayer.Bubble(style: viewModel.style)
        maskLayer.setBubble(bubble, frame: bounds, animationDuration: animationDuration)
        
        animate(animations: {
            self.transform = .identity
            self.frame = frame
            self.imageWrapperView.frame = bounds
            self.accessoryContainerView.transform = .identity
            self.accessoryContainerView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            self.accessoryContainerView.alpha = 1
        }, completion: {
        })
    }
    
    override func prepare() {
        timeLabel.backgroundColor = .clear
        timeLabel.font = MessageFontSet.time.scaled
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textAlignment = .right
        timeLabel.textColor = .white
        statusImageView.contentMode = .left
        accessoryContainerView.backgroundColor = .clear
        accessoryContainerView.addSubview(timeLabel)
        accessoryContainerView.addSubview(statusImageView)
        addSubview(accessoryContainerView)
        super.prepare()
        layer.mask = maskLayer
    }
    
}
