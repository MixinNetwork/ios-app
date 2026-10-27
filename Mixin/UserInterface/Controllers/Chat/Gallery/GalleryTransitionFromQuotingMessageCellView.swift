import UIKit

class GalleryTransitionFromQuotingMessageCellView: GalleryTransitionFromMessageCellView {
    
    private let maskRadius = PhotoRepresentableMessageCell.quotingPhotoCornerRadius
    
    override func prepare() {
        super.prepare()
        imageWrapperView.clipsToBounds = true
    }
    
    override func transitionMaskToNone(frame: CGRect) {
        performCornerRadiusAnimation(from: maskRadius, to: 0)
    }
    
    override func transitionMask(frame: CGRect, viewModel: PhotoRepresentableMessageViewModel) {
        performCornerRadiusAnimation(from: 0, to: maskRadius)
    }
    
    private func performCornerRadiusAnimation(from: CGFloat, to: CGFloat) {
        imageWrapperView.layer.cornerRadius = to
        let anim = CABasicAnimation(keyPath: #keyPath(CALayer.cornerRadius))
        anim.duration = animationDuration
        anim.fromValue = from
        anim.toValue = to
        imageWrapperView.layer.add(anim, forKey: "corner_radius")
    }
    
}
