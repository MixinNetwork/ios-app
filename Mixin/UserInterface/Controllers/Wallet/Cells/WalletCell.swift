import UIKit
import MixinServices

final class WalletCell: UICollectionViewCell, TokenProportionRepresentableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
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
            iconImageView.isHidden = false
            iconImageView.image = R.image.privacy_wallet()
            tagLabel.isHidden = true
            loadProportions(
                tokens: digest.tokens,
                placeholder: .privacyWalletChains,
                usdBalanceSum: digest.usdBalanceSum
            )
        case let .common(wallet):
            switch wallet.category.knownCase {
            case .classic, .none:
                iconImageView.isHidden = true
                tagLabel.isHidden = true
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .commonWalletChains,
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .importedMnemonic:
                iconImageView.isHidden = true
                tagLabel.text = R.string.localizable.wallet_imported()
                tagLabel.isHidden = false
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .commonWalletChains,
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .importedPrivateKey:
                iconImageView.isHidden = true
                tagLabel.text = R.string.localizable.wallet_imported()
                tagLabel.isHidden = false
                let kind: Web3Chain.Kind? = .importedWalletKind(
                    chainIDs: digest.supportedChainIDs
                )
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .importedWallet(kind: kind),
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .watchAddress:
                iconImageView.isHidden = false
                iconImageView.image = R.image.watching_wallet()
                tagLabel.text = R.string.localizable.watching()
                tagLabel.isHidden = false
                let kind: Web3Chain.Kind? = .importedWalletKind(
                    chainIDs: digest.supportedChainIDs
                )
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .importedWallet(kind: kind),
                    usdBalanceSum: digest.usdBalanceSum
                )
            }
        }
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: digest.usdBalanceSum,
            fontSize: 22
        )
    }
    
}
