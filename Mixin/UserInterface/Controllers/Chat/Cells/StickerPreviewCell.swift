import UIKit

class StickerPreviewCell: UICollectionViewCell {
    
    let stickerView = AnimatedStickerView()
    
    var image: UIImage? {
        stickerView.imageView.image
    }
    
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
        stickerView.prepareForReuse()
    }
    
    private func loadSubview() {
        stickerView.layer.cornerRadius = 6
        stickerView.clipsToBounds = true
        stickerView.backgroundColor = .clear
        stickerView.contentMode = .scaleAspectFit
        contentView.addSubview(stickerView)
        stickerView.snp.makeEdgesEqualToSuperview()
    }
    
}
