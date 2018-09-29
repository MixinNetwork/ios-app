import UIKit
import YYImage

class AnimatedImageCollectionViewCell: UICollectionViewCell {
    
    lazy var imageView: YYAnimatedImageView = {
        let view = YYAnimatedImageView()
        view.autoPlayAnimatedImage = false
        view.contentMode = .scaleAspectFit
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
    
}
