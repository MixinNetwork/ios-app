import UIKit
import YYImage
import SDWebImage
import MixinServices

class StickerStoreBannerCell: UICollectionViewCell {
    
    private let imageView = YYAnimatedImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
    }
    
    func load(item: AlbumItem) {
        guard let banner = item.album.banner, let url = URL(string: banner) else {
            return
        }
        let context = stickerLoadContext(persistent: item.isAdded)
        imageView.sd_setImage(with: url, placeholderImage: nil, context: context)
    }
    
    func startAnimating() {
        imageView.autoPlayAnimatedImage = true
        imageView.startAnimating()
    }
    
    func stopAnimating() {
        imageView.autoPlayAnimatedImage = false
        imageView.stopAnimating()
    }
    
    private func loadSubview() {
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        imageView.snp.makeEdgesEqualToSuperview()
    }
    
}
