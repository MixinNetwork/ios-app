import UIKit

class AssetFilterConditionCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundView = UIView()
        backgroundView!.backgroundColor = R.color.text_field()
        backgroundView!.clipsToBounds = true
        backgroundView!.layer.borderColor = UIColor.disabledGray.cgColor
        backgroundView!.layer.borderWidth = 1
        backgroundView!.layer.cornerRadius = 8
        
        selectedBackgroundView = UIView()
        selectedBackgroundView!.backgroundColor = UIColor(rgbValue: 0xF5F7FA)
        selectedBackgroundView!.clipsToBounds = true
        selectedBackgroundView!.layer.cornerRadius = 8
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()
        let size = contentView.systemLayoutSizeFitting(layoutAttributes.size)
        var frame = layoutAttributes.frame
        frame.size = ceil(size)
        layoutAttributes.frame = frame
        return layoutAttributes
    }
    
}
