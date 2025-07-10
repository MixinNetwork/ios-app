import UIKit
import MixinServices

protocol TokenProportionRepresentableCell {
    var proportionStackView: UIStackView! { get }
}

enum TokenProportionPlaceholder {
    case privacyWalletSupportedChains
    case commonWalletSupportedChains
}

extension TokenProportionRepresentableCell {
    
    func loadProportions(tokens: [TokenDigest], placeholder: TokenProportionPlaceholder, usdBalanceSum: Decimal) {
        for view in proportionStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        switch tokens.count {
        case 0:
            proportionStackView.distribution = .fill
            let image = switch placeholder {
            case .privacyWalletSupportedChains:
                R.image.privacy_wallet_chains()
            case .commonWalletSupportedChains:
                R.image.classic_wallet_chains()
            }
            let imageView = UIImageView(image: image)
            proportionStackView.addArrangedSubview(imageView)
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
