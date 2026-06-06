import UIKit

final class WalletBenefitCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var benefit1Label: UILabel!
    @IBOutlet weak var benefit2Label: UILabel!
    @IBOutlet weak var benefit3Label: UILabel!
    
    var benefit: WalletBenefit? {
        didSet {
            switch benefit {
            case .privacyWallet:
                titleLabel.text = R.string.localizable.wallet_home_privacy_wallet_reason_title()
                benefit1Label.text = "• " + R.string.localizable.wallet_home_privacy_wallet_reason_1()
                benefit2Label.text = "• " + R.string.localizable.wallet_home_privacy_wallet_reason_2()
                benefit3Label.text = "• " + R.string.localizable.wallet_home_privacy_wallet_reason_3()
            case .commonWallet:
                titleLabel.text = R.string.localizable.wallet_home_common_wallet_reason_title()
                benefit1Label.text = "• " + R.string.localizable.wallet_home_common_wallet_reason_1()
                benefit2Label.text = "• " + R.string.localizable.wallet_home_common_wallet_reason_2()
                benefit3Label.text = "• " + R.string.localizable.wallet_home_common_wallet_reason_3()
            case nil:
                break
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let labels: [UILabel] = [
            titleLabel,
            benefit1Label,
            benefit2Label,
            benefit3Label,
        ]
        for label in labels {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
        }
    }
    
}
