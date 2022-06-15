import UIKit

class PreviewWallpaperCell: UICollectionViewCell {
    
    @IBOutlet weak var wallpaperImageView: WallpaperImageView!
    
    var wallpaper: Wallpaper? {
        didSet {
            wallpaperImageView.wallpaper = wallpaper
        }
    }
    
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        wallpaper = nil
    }
    
}
