import UIKit

final class PerpsProCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpsProCellDidSelectEnter(_ cell: PerpsProCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tagLabel: InsetLabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var enterButton: UIButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.text = "Mixin Perps"
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        tagLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        tagLabel.layer.cornerRadius = 4
        tagLabel.layer.masksToBounds = true
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        descriptionLabel.text = R.string.localizable.trade_pro_description()
        enterButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.trade_now(),
            scalingByFontSize: 14
        )
    }
    
    @IBAction func enterPerpsPro(_ sender: Any) {
        delegate?.perpsProCellDidSelectEnter(self)
    }
    
}
