import UIKit
import MixinServices

final class WalletCell: UICollectionViewCell, TokenProportionRepresentableCell {
    
    enum Accessory {
        case disclosure
        case external
        case selection
    }
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var proportionStackView: UIStackView!
    @IBOutlet weak var accessoryImageView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            guard accessory == .selection else {
                return
            }
            accessoryImageView.image = isSelected
            ? R.image.ic_selected()
            : R.image.ic_deselected()
        }
    }
    
    var accessory: Accessory = .disclosure {
        didSet {
            accessoryImageView.image = switch accessory {
            case .disclosure:
                R.image.ic_accessory_disclosure()
            case .external:
                R.image.external_indicator_arrow_bold()
            case .selection:
                isSelected ? R.image.ic_selected() : R.image.ic_deselected()
            }
        }
    }
    
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
            titleLabel.text = switch digest.legacyClassicWalletRenaming {
            case .notInvolved, .done:
                wallet.name
            case .required:
                R.string.localizable.common_wallet()
            }
            switch wallet.category.knownCase {
            case .classic:
                iconImageView.isHidden = true
                tags = []
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .commonWalletChains,
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .importedMnemonic:
                iconImageView.isHidden = true
                tags = [.plain(R.string.localizable.wallet_imported())]
                if !hasSecret {
                    tags.append(.warning(R.string.localizable.no_key()))
                }
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .commonWalletChains,
                    usdBalanceSum: digest.usdBalanceSum
                )
            case .importedPrivateKey:
                iconImageView.isHidden = true
                tags = [.plain(R.string.localizable.wallet_imported())]
                if !hasSecret {
                    tags.append(.warning(R.string.localizable.no_key()))
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
                iconImageView.isHidden = false
                iconImageView.image = R.image.watching_wallet()
                tags = [.plain(R.string.localizable.watching())]
                let kind: Web3Chain.Kind? = .singleKindWallet(
                    chainIDs: digest.supportedChainIDs
                )
                loadProportions(
                    tokens: digest.tokens,
                    placeholder: .singleKindWallet(kind: kind),
                    usdBalanceSum: digest.usdBalanceSum
                )
            }
        case let .safe(wallet):
            titleLabel.text = wallet.name
            iconImageView.isHidden = false
            iconImageView.image = R.image.safe_vault()
            tags = [.plain(wallet.role.localizedDescription)]
            loadProportions(
                tokens: digest.tokens,
                placeholder: .safeVault(chainID: wallet.chainID),
                usdBalanceSum: digest.usdBalanceSum
            )
        }
        load(tags: tags)
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: digest.usdBalanceSum,
            fontSize: 22
        )
    }
    
}

extension WalletCell {
    
    private enum Tag {
        case plain(String)
        case warning(String)
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
            case .plain(let text):
                label.backgroundColor = R.color.background_quaternary()
                label.textColor = R.color.text_quaternary()
                label.text = text
            case .warning(let text):
                label.backgroundColor = R.color.market_red()!.withAlphaComponent(0.2)
                label.textColor = R.color.market_red()
                label.text = text
            }
        }
    }
    
}
