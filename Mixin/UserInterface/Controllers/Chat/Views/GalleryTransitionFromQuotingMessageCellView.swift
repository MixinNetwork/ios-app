import UIKit

class GalleryTransitionFromQuotingMessageCellView: GalleryTransitionFromMessageCellView {
    
    override func prepare() {
        super.prepare()
        imageWrapperView.clipsToBounds = true
    }
    
    override func transitionMaskToNone(frame: CGRect) {
        animate(animations: {
            self.imageWrapperView.layer.cornerRadius = 0
        })
    }
    
    override func transitionMask(frame: CGRect, viewModel: PhotoRepresentableMessageViewModel) {
        animate(animations: {
            self.imageWrapperView.layer.cornerRadius = PhotoRepresentableMessageCell.quotingPhotoCornerRadius
        })
    }
    
}
