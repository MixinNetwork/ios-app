import UIKit
import MixinServices

protocol TokenProportionRepresentableCell {
    var proportionStackView: UIStackView! { get }
}

enum TokenProportionPlaceholder {
    
    enum Chain {
        case bitcoin
        case ethereum
        case litecoin
        case polygon
        case solana
    }
    
    case privacyWalletChains
    case commonWalletChains
    case evmChains
    case chain(Chain)
    
    static func singleKindWallet(kind: Web3Chain.Kind?) -> TokenProportionPlaceholder? {
        switch kind {
        case .evm:
                .evmChains
        case .solana:
                .chain(.solana)
        case .none:
                .none
        }
    }
    
    static func safeVault(chainID: String?) -> TokenProportionPlaceholder? {
        switch chainID {
        case ChainID.bitcoin:
                .chain(.bitcoin)
        case ChainID.ethereum:
                .chain(.ethereum)
        case ChainID.litecoin:
                .chain(.litecoin)
        case ChainID.polygon:
                .chain(.polygon)
        default:
                .none
        }
    }
    
}

extension TokenProportionRepresentableCell {
    
    func loadProportions(tokens: [TokenDigest], placeholder: TokenProportionPlaceholder?, usdBalanceSum: Decimal) {
        for view in proportionStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        switch tokens.count {
        case 0:
            proportionStackView.distribution = .fill
            if let placeholder {
                let image = switch placeholder {
                case .privacyWalletChains:
                    R.image.privacy_wallet_chains()
                case .commonWalletChains:
                    R.image.classic_wallet_chains()
                case .evmChains:
                    R.image.evm_chains()
                case .chain(.bitcoin):
                    R.image.bitcoin_chain()
                case .chain(.ethereum):
                    R.image.ethereum_chain()
                case .chain(.litecoin):
                    R.image.litecoin_chain()
                case .chain(.polygon):
                    R.image.polygon_chain()
                case .chain(.solana):
                    R.image.solana_chain()
                }
                let imageView = UIImageView(image: image)
                proportionStackView.addArrangedSubview(imageView)
            }
            let placeholder = UIView()
            placeholder.backgroundColor = .clear
            proportionStackView.addArrangedSubview(placeholder)
        case 1, 2, 3:
            proportionStackView.distribution = .fillEqually
            var percentages = tokens.prefix(tokens.count - 1).map { token in
                NSDecimalNumber(decimal: token.decimalValue / usdBalanceSum)
                    .rounding(accordingToBehavior: NSDecimalNumberHandler.percentRoundingHandler)
                    .decimalValue
            }
            percentages.append(1 - percentages.reduce(0, +))
            addSingleTokenProportionView(count: tokens.count) { iconView, label, index in
                let token = tokens[index]
                iconView.setIcon(tokenIconURL: URL(string: token.iconURL))
                label.text = NumberFormatter.simplePercentage.string(decimal: percentages[index])
            }
            for _ in 0..<3 - tokens.count {
                let placeholder = UIView()
                placeholder.backgroundColor = .clear
                proportionStackView.addArrangedSubview(placeholder)
            }
        default:
            proportionStackView.distribution = .fillEqually
            let percentages = tokens.prefix(2).map { token in
                NSDecimalNumber(decimal: token.decimalValue / usdBalanceSum)
                    .rounding(accordingToBehavior: NSDecimalNumberHandler.percentRoundingHandler)
                    .decimalValue
            }
            addSingleTokenProportionView(count: 2) { iconView, label, index in
                let token = tokens[index]
                iconView.setIcon(tokenIconURL: URL(string: token.iconURL))
                label.text = NumberFormatter.simplePercentage.string(decimal: percentages[index])
            }
            let iconView = StackedTokenIconView()
            iconView.size = .small
            let label = UILabel()
            label.font = .systemFont(ofSize: 14)
            label.textColor = R.color.text_quaternary()
            label.text = NumberFormatter.simplePercentage.string(decimal: 1 - percentages.reduce(0, +))
            let stackView = UIStackView(arrangedSubviews: [iconView, label])
            stackView.axis = .horizontal
            stackView.spacing = 4
            proportionStackView.addArrangedSubview(stackView)
            iconView.setIcons(urls: tokens[2...].map(\.iconURL))
        }
    }
    
    private func addSingleTokenProportionView(
        count: Int,
        configurate: (PlainTokenIconView, UILabel, Int) -> Void
    ) {
        for i in 0..<count {
            let iconFrame = CGRect(x: 0, y: 0, width: 18, height: 18)
            let iconView = PlainTokenIconView(frame: iconFrame)
            let label = UILabel()
            label.font = .systemFont(ofSize: 14)
            label.textColor = R.color.text_quaternary()
            let stackView = UIStackView(arrangedSubviews: [iconView, label])
            stackView.axis = .horizontal
            stackView.spacing = 4
            proportionStackView.addArrangedSubview(stackView)
            iconView.snp.makeConstraints { make in
                make.size.equalTo(iconFrame.size)
            }
            configurate(iconView, label, i)
        }
    }
    
}
