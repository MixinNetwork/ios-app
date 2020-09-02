import UIKit
import YYImage
import Lottie
import MixinServices

class AnimatedStickerView: UIView {
    
    override var contentMode: UIView.ContentMode {
        didSet {
            imageViewIfLoaded?.contentMode = contentMode
            animationViewIfLoaded?.contentMode = contentMode
        }
    }
    
    private(set) weak var imageViewIfLoaded: YYAnimatedImageView?
    private(set) weak var animationViewIfLoaded: LOTAnimationView?
    
    private lazy var imageView: YYAnimatedImageView = {
        let view = YYAnimatedImageView()
        view.autoPlayAnimatedImage = false
        view.contentMode = contentMode
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        imageViewIfLoaded = view
        return view
    }()
    
    private lazy var animationView: LOTAnimationView = {
        let view = LOTAnimationView()
        view.contentMode = contentMode
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        animationViewIfLoaded = view
        return view
    }()
    
    private weak var animationDownloadToken: LottieAnimationLoader.Token?
    
    deinit {
        animationDownloadToken?.cancel()
    }
    
    func prepareForReuse() {
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
    
    func load(message: MessageItem) {
        guard let assetUrl = message.assetUrl, let url = URL(string: assetUrl) else {
            return
        }
        if message.assetTypeIsJSON {
            animationView.isHidden = false
            imageViewIfLoaded?.isHidden = true
            animationDownloadToken = LottieAnimationLoader.shared.loadAnimation(with: url, completion: { [weak self] (composition) in
                guard let self = self else {
                    return
                }
                self.animationView.sceneModel = composition
                self.animationView.loopAnimation = true
                self.animationView.play()
            })
        } else {
            animationViewIfLoaded?.isHidden = true
            imageView.isHidden = false
            let context = stickerLoadContext(category: message.assetCategory)
            imageView.sd_setImage(with: URL(string: assetUrl),
                                  placeholderImage: nil,
                                  context: context)
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
