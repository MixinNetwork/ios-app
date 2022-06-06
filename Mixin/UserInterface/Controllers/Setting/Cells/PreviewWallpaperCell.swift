import UIKit

class PreviewWallpaperCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var iconView: UIImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        iconView.isHidden = true
    }
    
    func updateUI(isSelected: Bool) {
        layer.borderColor = isSelected ? UIColor.theme.cgColor : UIColor.background.cgColor
    }
    
}
