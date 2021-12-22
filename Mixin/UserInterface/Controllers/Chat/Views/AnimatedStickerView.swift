import UIKit
import SDWebImage
import Lottie
import MixinServices

class AnimatedStickerView: UIView {
    
    override var contentMode: UIView.ContentMode {
        didSet {
            imageViewIfLoaded?.contentMode = contentMode
            animationViewIfLoaded?.contentMode = contentMode
        }
    }
    
    var autoPlayAnimatedImage = false {
        didSet {
            imageViewIfLoaded?.autoPlayAnimatedImage = autoPlayAnimatedImage
        }
    }
    
    private(set) weak var imageViewIfLoaded: SDAnimatedImageView?
    private(set) weak var animationViewIfLoaded: LOTAnimationView?
    
    private lazy var imageView: SDAnimatedImageView = {
        let view = SDAnimatedImageView()
        view.autoPlayAnimatedImage = autoPlayAnimatedImage
        view.contentMode = contentMode
        view.maxBufferSize = .max
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
            imageView.contentMode = contentMode
        }
        animationDownloadToken?.cancel()
        if let animationView = animationViewIfLoaded {
            animationView.animation = nil
            animationView.contentMode = contentMode
        }
    }
    
    func load(sticker: StickerItem) {
        guard let url = URL(string: sticker.assetUrl) else {
            return
        }
        if sticker.assetTypeIsJSON {
            loadAnimation(url: url)
        } else {
            imageView.isHidden = false
            animationViewIfLoaded?.isHidden = true
            imageView.sd_setImage(with: url,
                                  placeholderImage: nil,
                                  context: sticker.imageLoadContext)
        }
    }
    
    func load(message: MessageItem) {
        let url: URL
        if let assetUrl = message.assetUrl, let u = URL(string: assetUrl) {
            url = u
        } else if let mediaURL = message.mediaUrl, let u = URL(string: mediaURL) {
            url = u
        } else {
            return
        }
        if message.assetTypeIsJSON {
            loadAnimation(url: url)
        } else {
            animationViewIfLoaded?.isHidden = true
            imageView.isHidden = false
            let context = stickerLoadContext(category: message.assetCategory)
            imageView.sd_setImage(with: url,
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
    
    private func loadAnimation(url: URL) {
        animationView.isHidden = false
        imageViewIfLoaded?.isHidden = true
        animationDownloadToken = LottieAnimationLoader.shared.loadAnimation(with: url, completion: { [weak self] (composition) in
            guard let self = self else {
                return
            }
            self.animationView.sceneModel = composition
            if self.autoPlayAnimatedImage {
                self.animationView.loopAnimation = true
                self.animationView.play()
            }
        })
    }
    
}
