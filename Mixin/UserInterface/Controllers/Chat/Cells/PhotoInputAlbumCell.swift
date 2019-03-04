import UIKit

class PhotoInputAlbumCell: UICollectionViewCell {
    
    @IBOutlet weak var textLabel: UILabel!
    
    override var isSelected: Bool {
        didSet {
            textLabel.textColor = isSelected ? UIColor(rgbValue: 0x3A3C3E) : UIColor(rgbValue: 0xBBBEC3)
        }
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let sizeToFit = CGSize(width: UIView.layoutFittingExpandedSize.width,
                               height: layoutAttributes.size.height)
        let size = contentView.systemLayoutSizeFitting(sizeToFit)
        layoutAttributes.frame.size.width = ceil(size.width)
        return layoutAttributes
    }
    
}
