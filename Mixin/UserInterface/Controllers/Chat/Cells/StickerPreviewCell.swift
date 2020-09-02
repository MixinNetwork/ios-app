import UIKit
import Alamofire
import YYImage
import Lottie
import MixinServices

class StickerPreviewCell: UICollectionViewCell {
    
    var image: UIImage? {
        imageViewIfLoaded?.image
    }
    
    private lazy var imageView: YYAnimatedImageView = {
        let view = YYAnimatedImageView()
        view.autoPlayAnimatedImage = false
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        imageViewIfLoaded = view
        return view
    }()
    
    private lazy var animationView: LOTAnimationView = {
        let view = LOTAnimationView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        animationViewIfLoaded = view
        return view
    }()
    
    private weak var imageViewIfLoaded: YYAnimatedImageView?
    private weak var animationViewIfLoaded: LOTAnimationView?
    private weak var animationDownloadToken: LottieAnimationLoader.Token?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if let imageView = imageViewIfLoaded {
            imageView.sd_cancelCurrentImageLoad()
            imageView.image = nil
        }
        animationDownloadToken?.cancel()
        if let animationView = animationViewIfLoaded {
            animationView.animation = nil
        }
    }
    
    func load(sticker: StickerItem) {
        guard let url = URL(string: sticker.assetUrl) else {
            return
        }
        if sticker.assetTypeIsJSON {
            animationView.isHidden = false
            imageViewIfLoaded?.isHidden = true
            animationDownloadToken = LottieAnimationLoader.shared.loadAnimation(with: url) { [weak self] (animation) in
                self?.animationView.sceneModel = animation
            }
        } else {
            imageView.isHidden = false
            animationViewIfLoaded?.isHidden = true
            imageView.sd_setImage(with: url,
                                  placeholderImage: nil,
                                  context: sticker.imageLoadContext)
        }
    }
    
    func load(image: UIImage?, contentMode: UIView.ContentMode) {
        imageView.isHidden = false
        animationViewIfLoaded?.isHidden = true
        imageView.image = image
        imageView.contentMode = contentMode
    }
    
    func load(imageURL url: URL, contentMode: UIView.ContentMode) {
        imageView.isHidden = false
        animationViewIfLoaded?.isHidden = true
        imageView.sd_setImage(with: url)
        imageView.contentMode = contentMode
    }
    
    func startAnimating() {
        if let imageView = imageViewIfLoaded {
            imageView.autoPlayAnimatedImage = true
            imageView.startAnimating()
        }
        if let animationView = animationViewIfLoaded {
            animationView.loopAnimation = true
            animationView.play()
        }
    }
    
    func stopAnimating() {
        if let imageView = imageViewIfLoaded {
            imageView.autoPlayAnimatedImage = false
            imageView.stopAnimating()
        }
        if let animationView = animationViewIfLoaded {
            animationView.pause()
        }
    }
    
}
