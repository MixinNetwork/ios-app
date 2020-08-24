import UIKit
import YYImage
import MixinServices

class StickerPreviewCell: UICollectionViewCell {
    
    var image: UIImage? {
        imageView.image
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
        return view
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
    func load(sticker: StickerItem) {
        if let url = URL(string: sticker.assetUrl) {
            imageView.sd_setImage(with: url,
                                  placeholderImage: nil,
                                  context: sticker.imageLoadContext)
        }
    }
    
    func load(image: UIImage?, contentMode: UIView.ContentMode) {
        imageView.image = image
        imageView.contentMode = contentMode
    }
    
    func load(imageURL url: URL, contentMode: UIView.ContentMode) {
        imageView.sd_setImage(with: url)
        imageView.contentMode = contentMode
    }
    
    func startAnimating() {
        imageView.autoPlayAnimatedImage = true
        imageView.startAnimating()
    }
    
    func stopAnimating() {
        imageView.autoPlayAnimatedImage = false
        imageView.stopAnimating()
    }
    
}
