import UIKit

final class SwapPriceInputCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var networkLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var priceRepresentationLabel: UILabel!
    @IBOutlet weak var tokenNameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.masksToBounds = true
        contentView.layer.cornerRadius = 8
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.price()
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
    }
    
}
