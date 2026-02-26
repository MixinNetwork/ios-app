import UIKit
import MixinServices

final class PerpetualPositionWalletCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    
    private weak var tagLabel: InsetLabel?
    
    var walletTag: Wallet.Tag? {
        didSet {
            if let walletTag {
                let label: InsetLabel
                if let tagLabel {
                    label = tagLabel
                } else {
                    label = InsetLabel()
                    label.layer.cornerRadius = 4
                    label.layer.masksToBounds = true
                    label.font = .preferredFont(forTextStyle: .caption1)
                    label.adjustsFontForContentSizeCategory = true
                    label.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
                    label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                    contentStackView.addArrangedSubview(label)
                    self.tagLabel = label
                }
                switch walletTag {
                case .plain(let text):
                    label.backgroundColor = R.color.background_quaternary()
                    label.textColor = R.color.text_quaternary()
                    label.text = text
                case .warning(let text):
                    label.backgroundColor = R.color.market_red()!.withAlphaComponent(0.2)
                    label.textColor = R.color.market_red()
                    label.text = text
                case .safeOwner(let text):
                    label.backgroundColor = UIColor(displayP3RgbValue: 0xFFAA00).withAlphaComponent(0.6)
                    label.textColor = .white
                    label.text = text
                }
            } else {
                tagLabel?.removeFromSuperview()
                tagLabel = nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
}
