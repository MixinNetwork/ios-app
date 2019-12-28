import UIKit

class AssetFilterConditionCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundView = UIView()
        backgroundView!.clipsToBounds = true
        backgroundView!.layer.borderColor = R.color.line()!.cgColor
        backgroundView!.layer.borderWidth = 1
        backgroundView!.layer.cornerRadius = 8
        
        selectedBackgroundView = UIView()
        selectedBackgroundView!.backgroundColor = .inputBackground
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
