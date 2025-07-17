import UIKit
import MixinServices

final class WalletCell: UICollectionViewCell, TokenProportionRepresentableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var privacyIconImageView: UIImageView!
    @IBOutlet weak var tagLabel: InsetLabel!
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
        tagLabel.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        tagLabel.layer.cornerRadius = 4
        tagLabel.layer.masksToBounds = true
    }
    
    func load(digest: WalletDigest) {
        titleLabel.text = digest.wallet.localizedName
        switch digest.wallet {
        case .privacy:
            privacyIconImageView.isHidden = false
            tagLabel.isHidden = true
            loadProportions(
                tokens: digest.tokens,
                placeholder: .privacyWalletSupportedChains,
                usdBalanceSum: digest.usdBalanceSum
            )
        case let .common(wallet):
            privacyIconImageView.isHidden = true
            switch wallet.category.knownCase {
            case .classic, .none:
                tagLabel.isHidden = true
            case .importedMnemonic:
                tagLabel.text = R.string.localizable.wallet_imported()
                tagLabel.isHidden = false
            }
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
