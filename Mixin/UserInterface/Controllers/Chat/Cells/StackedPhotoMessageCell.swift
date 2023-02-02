import UIKit

class StackedPhotoMessageCell: ImageMessageCell {
    
    static let contentCornerRadius: CGFloat = 13
    
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
        updateAppearance(highlight: false, animated: false)
        messageContentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        selectedOverlapView.layer.cornerRadius = Self.contentCornerRadius
        backgroundImageView.removeFromSuperview()
        stackedPhotoView.backgroundColor = .clear
        statusImageView.alpha = 0.9
    }
    
}
