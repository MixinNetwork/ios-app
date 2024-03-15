import UIKit

final class SnapshotFilterConditionCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundView = {
            let view = UIView()
            view.layer.masksToBounds = true
            view.layer.borderColor = R.color.line()!.cgColor
            view.layer.borderWidth = 1
            view.layer.cornerRadius = 8
            return view
        }()
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .inputBackground
            view.layer.masksToBounds = true
            view.layer.cornerRadius = 8
            return view
        }()
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
