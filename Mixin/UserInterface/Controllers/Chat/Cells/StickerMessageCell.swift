import UIKit
import YYImage
import Lottie
import Alamofire
import MixinServices

class StickerMessageCell: DetailInfoMessageCell {
    
    static let contentCornerRadius: CGFloat = 6
    
    private static let defaultOverlapImage = UIColor.black.image
    
    let imageWrapperView = UIView()
    let contentImageView = YYAnimatedImageView()
    let lottieAnimationView = LOTAnimationView()
    
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
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageView.image = nil
        lottieAnimationDownloadToken?.cancel()
        lottieAnimationView.sceneModel = nil
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? StickerMessageViewModel {
            imageWrapperView.frame = viewModel.contentFrame
            if let assetUrl = viewModel.message.assetUrl, let url = URL(string: assetUrl) {
                if viewModel.message.assetTypeIsJSON {
                    lottieAnimationView.isHidden = false
                    contentImageView.isHidden = true
                    lottieAnimationDownloadToken = LottieAnimationLoader.shared.loadAnimation(with: url, completion: { [weak self] (composition) in
                        guard let self = self else {
                            return
                        }
                        self.lottieAnimationView.sceneModel = composition
                        self.lottieAnimationView.loopAnimation = true
                        self.lottieAnimationView.play()
                    })
                } else {
                    lottieAnimationView.isHidden = true
                    contentImageView.isHidden = false
                    let context = stickerLoadContext(category: viewModel.message.assetCategory)
                    contentImageView.sd_setImage(with: URL(string: assetUrl), placeholderImage: nil, context: context)
                }
            }
        }
    }
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        let overlapImage = contentImageView.image ?? Self.defaultOverlapImage
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
        
        contentImageView.frame = imageWrapperView.bounds
        contentImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentImageView.contentMode = .scaleAspectFill
        imageWrapperView.addSubview(contentImageView)
        
        lottieAnimationView.frame = imageWrapperView.bounds
        lottieAnimationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        lottieAnimationView.contentMode = .scaleAspectFill
        imageWrapperView.addSubview(lottieAnimationView)
        
        super.prepare()
        backgroundImageView.removeFromSuperview()
    }
    
}
