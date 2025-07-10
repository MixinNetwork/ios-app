import UIKit
import MixinServices

final class WalletCell: UICollectionViewCell, TokenProportionRepresentableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var privacyIconImageView: UIImageView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var proportionStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
    }
    
    func load(digest: WalletDigest) {
        switch digest.wallet {
        case .privacy:
            titleLabel.text = R.string.localizable.privacy_wallet()
            privacyIconImageView.isHidden = false
            loadProportions(
                tokens: digest.tokens,
                placeholder: .privacyWalletSupportedChains,
                usdBalanceSum: digest.usdBalanceSum
            )
        case let .common(wallet):
            titleLabel.text = wallet.localizedName
            privacyIconImageView.isHidden = true
            loadProportions(
                tokens: digest.tokens,
                placeholder: .commonWalletSupportedChains,
                usdBalanceSum: digest.usdBalanceSum
            )
        }
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: digest.usdBalanceSum,
            fontSize: 22
        )
    }
    
}
