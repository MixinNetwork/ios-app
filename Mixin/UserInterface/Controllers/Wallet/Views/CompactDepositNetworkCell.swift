import UIKit

class CompactDepositNetworkCell: UICollectionViewCell {

    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundView = {
            let view = UIView()
            view.clipsToBounds = true
            view.layer.borderColor = R.color.line()!.cgColor
            view.layer.borderWidth = 1
            view.layer.cornerRadius = 8
            return view
        }()
        
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .inputBackground
            view.clipsToBounds = true
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
