import UIKit

final class SwapNoOpenOrderCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        contentView.layer.masksToBounds = true
        label.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .regular),
            adjustForContentSize: true
        )
        label.text = R.string.localizable.no_orders().uppercased()
    }
    
}
