import UIKit
import FLAnimatedImage

class StickerCollectionViewCell: UICollectionViewCell {
    
    lazy var imageView: FLAnimatedImageView = {
        let view = FLAnimatedImageView()
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
}
