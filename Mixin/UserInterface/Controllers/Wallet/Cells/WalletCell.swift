import UIKit
import MixinServices

final class WalletCell: UICollectionViewCell, TokenProportionRepresentableCell {
    
    private enum Tag {
        case watching
        case imported
        case noKey
    }
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var proportionStackView: UIStackView!
    
    private var tagLabels: [InsetLabel] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
    }
    
    func load(digest: WalletDigest, hasSecret: Bool) {
        var tags: [Tag]
        switch digest.wallet {
        case .privacy:
            titleLabel.text = R.string.localizable.privacy_wallet()
            iconImageView.isHidden = false
            iconImageView.image = R.image.privacy_wallet()
            tags = []
            loadProportions(
                tokens: digest.tokens,
                placeholder: .privacyWalletChains,
                usdBalanceSum: digest.usdBalanceSum
            )
        case let .common(wallet):
            switch wallet.category.knownCase {
            case .classic:
                titleLabel.text = if digest.hasLegacyAddresses {
                    R.string.localizable.common_wallet()
                } else {
                    wallet.name
                }
                iconImageView.isHidden = true
                tags = []
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .commonWalletChains,
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .importedMnemonic:
                titleLabel.text = wallet.name
                iconImageView.isHidden = true
                tags = [.imported]
                if !hasSecret {
                    tags.append(.noKey)
                }
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .commonWalletChains,
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .importedPrivateKey:
                titleLabel.text = wallet.name
                iconImageView.isHidden = true
                tags = [.imported]
                if !hasSecret {
                    tags.append(.noKey)
                }
                let kind: Web3Chain.Kind? = .singleKindWallet(
                    chainIDs: digest.supportedChainIDs
                )
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .singleKindWallet(kind: kind),
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .watchAddress, .none:
                titleLabel.text = wallet.name
                iconImageView.isHidden = false
                iconImageView.image = R.image.watching_wallet()
                tags = [.watching]
                let kind: Web3Chain.Kind? = .singleKindWallet(
                    chainIDs: digest.supportedChainIDs
                )
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .singleKindWallet(kind: kind),
                    usdBalanceSum: digest.usdBalanceSum
                )
            }
        }
        load(tags: tags)
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: digest.usdBalanceSum,
            fontSize: 22
        )
    }
    
    private func load(tags: [Tag]) {
        if tagLabels.count > tags.count {
            for label in tagLabels.suffix(tagLabels.count - tags.count) {
                label.removeFromSuperview()
            }
        } else {
            while tagLabels.count < tags.count {
                let label = InsetLabel()
                label.layer.cornerRadius = 4
                label.layer.masksToBounds = true
                label.font = .preferredFont(forTextStyle: .caption1)
                label.adjustsFontForContentSizeCategory = true
                label.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
                label.setContentCompressionResistancePriority(.required, for: .horizontal)
                tagLabels.append(label)
            }
        }
        for label in tagLabels.prefix(tags.count) where label.superview == nil {
            titleStackView.addArrangedSubview(label)
        }
        for (index, tag) in tags.enumerated() {
            let label = tagLabels[index]
            switch tag {
            case .watching:
                label.backgroundColor = R.color.background_quaternary()
                label.textColor = R.color.text_quaternary()
                label.text = R.string.localizable.watching()
            case .imported:
                label.backgroundColor = R.color.background_quaternary()
                label.textColor = R.color.text_quaternary()
                label.text = R.string.localizable.wallet_imported()
            case .noKey:
                label.backgroundColor = R.color.market_red()!.withAlphaComponent(0.2)
                label.textColor = R.color.market_red()
                label.text = R.string.localizable.no_key()
            }
        }
    }
    
}
