import UIKit

class StackedPhotoMessageCell: ImageMessageCell {
    
    private let stackedPhotoView = StackedPhotoView()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stackedPhotoView.viewModels = []
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? StackedPhotoMessageViewModel {
            if viewModel.quotedMessageViewModel == nil {
                stackedPhotoView.frame = viewModel.photoFrame
                if backgroundImageView.superview != nil {
                    backgroundImageView.removeFromSuperview()
                }
            } else {
                stackedPhotoView.frame = viewModel.photoFrame
                if backgroundImageView.superview == nil {
                    messageContentView.insertSubview(backgroundImageView, at: 0)
                }
            }
            stackedPhotoView.viewModels = viewModel.photoMessageViewModels
            selectedOverlapView.frame = stackedPhotoView.frame
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
        }
    }
    
    override func prepare() {
        messageContentView.addSubview(stackedPhotoView)
        updateAppearance(highlight: false, animated: false)
        messageContentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        messageContentView.addSubview(selectedOverlapView)
        backgroundImageView.removeFromSuperview()
        statusImageView.isHidden = true
        stackedPhotoView.backgroundColor = .clear
    }
    
}
