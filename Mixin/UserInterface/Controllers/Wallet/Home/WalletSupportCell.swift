import UIKit

final class WalletSupportCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var accessoryImageView: UIImageView!
    
    var content: WalletSupport? {
        didSet {
            switch content {
            case .contactUs:
                iconImageView.image = R.image.wallet_support_contact_us()
                titleLabel.text = R.string.localizable.wallet_home_contact_us()
                subtitleLabel.text = R.string.localizable.leave_message_to_team_mixin()
                accessoryImageView.image = R.image.ic_accessory_disclosure()
            case .helpCenter:
                iconImageView.image = R.image.wallet_support_help_center()
                titleLabel.text = R.string.localizable.help_center()
                subtitleLabel.text = R.string.localizable.wallet_home_help_center_desc()
                accessoryImageView.image = R.image.external_indicator_arrow_bold()
            case nil:
                break
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        subtitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
}
