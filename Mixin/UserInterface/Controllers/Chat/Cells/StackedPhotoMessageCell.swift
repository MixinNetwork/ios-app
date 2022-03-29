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
            stackedPhotoView.viewModels = viewModel.photoMessageViewModels
            stackedPhotoView.frame = viewModel.stackedPhotoViewFrame
            selectedOverlapView.frame = viewModel.photoFrame
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
        }
    }

    override func prepare() {
        messageContentView.addSubview(stackedPhotoView)
        messageContentView.addSubview(trailingInfoBackgroundView)
        updateAppearance(highlight: false, animated: false)
        super.prepare()
        messageContentView.addSubview(selectedOverlapView)
        selectedOverlapView.layer.cornerRadius = 13
        backgroundImageView.removeFromSuperview()
        statusImageView.isHidden = true
        stackedPhotoView.backgroundColor = .clear
    }
    
}
