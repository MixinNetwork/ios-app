import UIKit
import MixinServices

final class WalletCell: UICollectionViewCell {
    
    enum WalletType {
        case privacy
        case classic
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var privacyIconImageView: UIImageView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var proportionStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
    }
    
    func load(digest: WalletDigest, type: WalletType) {
        switch type {
        case .privacy:
            titleLabel.text = R.string.localizable.privacy_wallet()
            privacyIconImageView.isHidden = false
        case .classic:
            titleLabel.text = R.string.localizable.classic_wallet()
            privacyIconImageView.isHidden = true
        }
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: digest.usdBalanceSum,
            fontSize: 22
        )
        
        for view in proportionStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        let tokens = digest.tokens
        switch tokens.count {
        case 0:
            proportionStackView.distribution = .fill
            let image = switch type {
            case .privacy:
                R.image.privacy_wallet_chains()
            case .classic:
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
                NSDecimalNumber(decimal: token.decimalValue / digest.usdBalanceSum)
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
                NSDecimalNumber(decimal: token.decimalValue / digest.usdBalanceSum)
                    .rounding(accordingToBehavior: NSDecimalNumberHandler.percentRoundingHandler)
                    .decimalValue
            }
            addSingleTokenProportionView(count: 2) { iconView, label, index in
                let token = tokens[index]
                iconView.setIcon(tokenIconURL: URL(string: token.iconURL))
                label.text = NumberFormatter.simplePercentage.string(decimal: percentages[index])
            }
            let iconView = MultipleTokenIconView()
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

extension WalletCell {
    
    private final class MultipleTokenIconView: UIView {
        
        private typealias IconWrapperView = StackedIconWrapperView<PlainTokenIconView>
        
        private let stackView = UIStackView()
        private let iconWrapperFrame = CGRect(x: 0, y: 0, width: 20, height: 20)
        
        private var wrapperViews: [IconWrapperView] = []
        
        private weak var addtionalCountLabel: InsetLabel?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubviews()
        }
        
        func setIcons(urls: [String]) {
            if urls.count > 3 {
                loadIconViews(count: 2) { _, wrapperView in
                    wrapperView.snp.makeConstraints { make in
                        make.width.equalTo(wrapperView.snp.height).offset(-6)
                    }
                }
                let label: InsetLabel
                if let l = addtionalCountLabel {
                    label = l
                } else {
                    let view = StackedIconWrapperView<InsetLabel>(margin: 2, frame: iconWrapperFrame)
                    view.backgroundColor = .clear
                    label = view.iconView
                    label.backgroundColor = R.color.background_quaternary()
                    label.textColor = R.color.icon_tint_tertiary()
                    label.font = .systemFont(ofSize: 8)
                    label.textAlignment = .center
                    label.adjustsFontSizeToFitWidth = true
                    label.minimumScaleFactor = 0.1
                    label.layer.cornerRadius = 9
                    label.layer.masksToBounds = true
                    label.contentInset = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 2)
                    stackView.addArrangedSubview(view)
                    view.snp.makeConstraints { make in
                        make.size.equalTo(20)
                    }
                }
                label.text = "+\(max(99, urls.count - 2))"
            } else {
                loadIconViews(count: urls.count) { index, wrapperView in
                    let offset = index == urls.count - 1 ? 0 : -6
                    wrapperView.snp.makeConstraints { make in
                        make.width.equalTo(wrapperView.snp.height).offset(offset)
                    }
                }
            }
            for (i, wrapperView) in wrapperViews.enumerated() {
                let url = URL(string: urls[i])
                wrapperView.iconView.setIcon(tokenIconURL: url)
            }
        }
        
        private func loadIconViews(count: Int, makeConstraints maker: (Int, IconWrapperView) -> Void) {
            guard wrapperViews.count != count else {
                return
            }
            for view in stackView.arrangedSubviews {
                view.removeFromSuperview()
            }
            wrapperViews = []
            for i in 0..<count {
                let view = IconWrapperView(margin: 2, frame: iconWrapperFrame)
                view.backgroundColor = .clear
                stackView.addArrangedSubview(view)
                wrapperViews.append(view)
                maker(i, view)
            }
        }
        
        private func loadSubviews() {
            backgroundColor = R.color.background()
            addSubview(stackView)
            stackView.snp.makeEdgesEqualToSuperview()
        }
        
    }
    
}
