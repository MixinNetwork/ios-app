import UIKit

class GalleryTransitionFromNonQuotingMessageCellView: GalleryTransitionFromMessageCellView {
    
    private let maskLayer = BubbleLayer()
    
    override func prepare() {
        super.prepare()
        layer.mask = maskLayer
    }
    
    override func load(viewController: GalleryItemViewController) {
        super.load(viewController: viewController)
        maskLayer.setBubble(.none, frame: bounds, animationDuration: 0)
        maskLayer.frame = bounds
    }
    
    override func loadMask(viewModel: PhotoRepresentableMessageViewModel) {
        let bubble = BubbleLayer.Bubble(style: viewModel.style)
        maskLayer.setBubble(bubble, frame: bounds, animationDuration: 0)
        maskLayer.bounds.size = imageWrapperView.bounds.size
        maskLayer.position = CGPoint(x: imageWrapperView.bounds.midX, y: imageWrapperView.bounds.midY)
    }
    
    override func transitionMaskToNone(frame: CGRect) {
        maskLayer.setBubble(.none, frame: frame, animationDuration: animationDuration)
    }
    
    override func transitionMask(frame: CGRect, viewModel: PhotoRepresentableMessageViewModel) {
        let bubble = BubbleLayer.Bubble(style: viewModel.style)
        maskLayer.setBubble(bubble, frame: frame, animationDuration: animationDuration)
    }
    
}
