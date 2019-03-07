import UIKit

class PhotoInputAlbumCell: UICollectionViewCell {
    
    @IBOutlet weak var textLabel: UILabel!
    
    private var cachedWidth: CGFloat?
    
    override var isSelected: Bool {
        didSet {
            textLabel.textColor = isSelected ? UIColor(rgbValue: 0x3A3C3E) : UIColor(rgbValue: 0xBBBEC3)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cachedWidth = nil
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        if let width = cachedWidth {
            layoutAttributes.frame.size.width = width
        } else {
            let sizeToFit = CGSize(width: UIView.layoutFittingExpandedSize.width,
                                   height: layoutAttributes.size.height)
            let size = contentView.systemLayoutSizeFitting(sizeToFit)
            let width = ceil(size.width)
            layoutAttributes.frame.size.width = width
            cachedWidth = width
        }
        return layoutAttributes
    }
    
}
