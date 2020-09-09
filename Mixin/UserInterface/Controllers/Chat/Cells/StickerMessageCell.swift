import UIKit
import YYImage
import Lottie
import Alamofire
import MixinServices

class StickerMessageCell: DetailInfoMessageCell {
    
    static let contentCornerRadius: CGFloat = 6
    
    private static let defaultOverlapImage = UIColor.black.image
    
    let imageWrapperView = UIView()
    let stickerView = AnimatedStickerView()
    
    lazy var selectedOverlapImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.alpha = 0
        imageView.tintColor = UIColor.black.withAlphaComponent(0.2)
        imageWrapperView.addSubview(imageView)
        return imageView
    }()
    
    private weak var lottieAnimationDownloadToken: LottieAnimationLoader.Token?
    
    override var contentFrame: CGRect {
        return imageWrapperView.frame
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerView.prepareForReuse()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? StickerMessageViewModel {
            imageWrapperView.frame = viewModel.contentFrame
            stickerView.load(message: viewModel.message)
        }
    }
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        let overlapImage = stickerView.imageViewIfLoaded?.image ?? Self.defaultOverlapImage
        selectedOverlapImageView.image = overlapImage?.withRenderingMode(.alwaysTemplate)
        selectedOverlapImageView.frame = imageWrapperView.bounds
        let shouldHighlight = highlight && !isMultipleSelecting
        UIView.animate(withDuration: animated ? highlightAnimationDuration : 0) {
            self.selectedOverlapImageView.alpha = shouldHighlight ? 1 : 0
        }
    }
    
    override func prepare() {
        messageContentView.addSubview(imageWrapperView)
        imageWrapperView.clipsToBounds = true
        imageWrapperView.layer.cornerRadius = Self.contentCornerRadius
        
        stickerView.frame = imageWrapperView.bounds
        stickerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        stickerView.contentMode = .scaleAspectFill
        stickerView.autoPlayAnimatedImage = true
        imageWrapperView.addSubview(stickerView)
        
        super.prepare()
        backgroundImageView.removeFromSuperview()
    }
    
}
