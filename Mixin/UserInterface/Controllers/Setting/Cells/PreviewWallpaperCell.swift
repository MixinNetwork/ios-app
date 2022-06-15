import UIKit

class PreviewWallpaperCell: UICollectionViewCell {
    
    @IBOutlet weak var wallpaperImageView: WallpaperImageView!
    @IBOutlet weak var pickFromPhotosImageView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            let color: UIColor = isSelected ? .theme : .clear
            contentView.layer.borderColor = color.cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.borderColor = UIColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentView.layer.borderColor = UIColor.clear.cgColor
    }
    
}
