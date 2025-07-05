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
    
    func load(digest: WalletDigest, kind: Wallet.Kind) {
        switch kind {
        case .privacy:
            titleLabel.text = R.string.localizable.privacy_wallet()
            privacyIconImageView.isHidden = false
        case .classic:
            titleLabel.text = R.string.localizable.common_wallet()
            privacyIconImageView.isHidden = true
        }
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: digest.usdBalanceSum,
            fontSize: 22
        )
        loadProportions(kind: kind, tokens: digest.tokens, usdBalanceSum: digest.usdBalanceSum)
    }
    
}
