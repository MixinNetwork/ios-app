import UIKit
import SDWebImage
import MixinServices

class StickerStoreBannerCell: UICollectionViewCell {
    
    let imageView = AnimatedStickerView()
    
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
        imageView.prepareForReuse()
    }
    
    private func loadSubview() {
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        imageView.snp.makeEdgesEqualToSuperview()
    }
    
}
