import UIKit
import SDWebImage
import MixinServices

class AnimatedStickerView: UIView {
    
    override var contentMode: UIView.ContentMode {
        didSet {
            imageView.contentMode = contentMode
        }
    }
    
    var autoPlayAnimatedImage = false {
        didSet {
            imageView.autoPlayAnimatedImage = autoPlayAnimatedImage
        }
    }
    
    let imageView = SDAnimatedImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    func prepareForReuse() {
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
        imageView.contentMode = contentMode
    }
    
    private func loadSubview() {
        imageView.autoPlayAnimatedImage = autoPlayAnimatedImage
        imageView.contentMode = contentMode
        imageView.maxBufferSize = .max
        addSubview(imageView)
        imageView.snp.makeEdgesEqualToSuperview()
    }
    
}

extension AnimatedStickerView {
    
    func load(sticker: StickerItem) {
        guard let url = URL(string: sticker.assetUrl) else {
            return
        }
        imageView.sd_setImage(with: url,
                              placeholderImage: nil,
                              context: sticker.imageLoadContext)
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
        let context = stickerLoadContext(persistent: message.isStickerAdded)
        imageView.sd_setImage(with: url,
                              placeholderImage: nil,
                              context: context)
    }
    
    func load(url: String?, persistent: Bool) {
        guard let url = url, let u = URL(string: url) else {
            return
        }
        imageView.sd_setImage(with: u,
                              placeholderImage: nil,
                              context: stickerLoadContext(persistent: persistent))
    }
    
    func load(image: UIImage?, contentMode: UIView.ContentMode) {
        imageView.image = image
        imageView.contentMode = contentMode
    }
    
    func load(imageURL url: URL, contentMode: UIView.ContentMode) {
        imageView.sd_setImage(with: url)
        imageView.contentMode = contentMode
    }
    
}

extension AnimatedStickerView {
    
    func startAnimating() {
        imageView.autoPlayAnimatedImage = true
        imageView.startAnimating()
    }
    
    func stopAnimating() {
        imageView.autoPlayAnimatedImage = false
        imageView.stopAnimating()
    }
    
}
