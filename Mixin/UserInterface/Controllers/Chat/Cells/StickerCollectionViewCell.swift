import UIKit
import YYImage

class StickerCollectionViewCell: UICollectionViewCell {
    
    lazy var imageView: YYAnimatedImageView = {
        let view = YYAnimatedImageView()
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
