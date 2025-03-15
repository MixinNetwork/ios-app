import UIKit
import MixinServices

final class WalletHeaderView: InfiniteTopView {
    
    @IBOutlet weak var contentView: UIStackView!
    
    @IBOutlet weak var fiatMoneyStackView: UIStackView!
    @IBOutlet weak var fiatMoneySymbolLabel: UILabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    @IBOutlet weak var changeStackView: UIStackView!
    @IBOutlet weak var changeLabel: InsetLabel!
    
    @IBOutlet weak var assetChartWrapperView: UIView!
    @IBOutlet weak var assetChartView: BarChartView!
    @IBOutlet weak var actionView: TokenActionView!
    
    @IBOutlet weak var leftAssetWrapperView: UIView!
    @IBOutlet weak var leftAssetSymbolLabel: UILabel!
    @IBOutlet weak var leftAssetPercentLabel: UILabel!
    
    @IBOutlet weak var middleAssetWrapperView: UIView!
    @IBOutlet weak var middleAssetSymbolLabel: UILabel!
    @IBOutlet weak var middleAssetPercentLabel: UILabel!
    
    @IBOutlet weak var rightAssetWrapperView: UIView!
    @IBOutlet weak var rightAssetSymbolLabel: UILabel!
    @IBOutlet weak var rightAssetPercentLabel: UILabel!
    
    @IBOutlet weak var pendingDepositView: UIView!
    @IBOutlet weak var pendingDepositButton: UIButton!
    @IBOutlet weak var pendingDepositStackView: UIStackView!
    @IBOutlet weak var pendingDepositIconStackView: UIStackView!
    @IBOutlet weak var pendingDepositLabel: UILabel!
    
    @IBOutlet weak var separatorView: UIView!
    
    @IBOutlet weak var contentViewBottomConstraint: NSLayoutConstraint!
    
    var showSnowfallEffect = false {
        didSet {
            if showSnowfallEffect {
                if snowfallLayer.superlayer == nil {
                    layer.insertSublayer(snowfallLayer, below: separatorView.layer)
                }
            } else {
                snowfallLayerIfLoaded?.removeFromSuperlayer()
            }
        }
    }
    
    private let btcValueAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.condensed(size: 14).scaled(),
        .kern: 0.7
    ]
    
    private let maxPendingDepositTokenIconCount = 3
    
    private lazy var snowfallLayer: CAEmitterLayer = {
        let cell = CAEmitterCell()
        cell.birthRate = 3
        cell.lifetime = 15
        cell.emissionRange = .pi
        cell.velocity = 5
        cell.velocityRange = 10
        cell.yAcceleration = 5
        cell.scale = 0.3
        cell.scaleRange = 0.15
        cell.spinRange = 1
        cell.color = snowflakeColor
        cell.contents = R.image.snowflake()!.cgImage
        
        let layer = CAEmitterLayer()
        layoutSnowfallLayer(layer)
        layer.masksToBounds = true
        layer.emitterShape = .line
        layer.emitterCells = [cell]
        
        snowfallLayerIfLoaded = layer
        return layer
    }()
    
    private weak var snowfallLayerIfLoaded: CAEmitterLayer?
    
    private var snowflakeColor: CGColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.4).cgColor
        } else {
            return UIColor(displayP3RgbValue: 0x9CABE9, alpha: 0.4).cgColor
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.setCustomSpacing(7, after: fiatMoneyStackView)
        contentView.setCustomSpacing(20, after: changeStackView)
        contentView.setCustomSpacing(30, after: assetChartWrapperView)
        contentView.setCustomSpacing(13, after: actionView)
        changeLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        changeLabel.alpha = 0
        pendingDepositButton.layer.masksToBounds = true
        pendingDepositButton.layer.cornerRadius = 18
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = snowfallLayerIfLoaded {
            layoutSnowfallLayer(layer)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            snowfallLayerIfLoaded?.emitterCells?.forEach { cell in
                cell.color = snowflakeColor
            }
        }
    }
    
    func reloadValues(tokens: [ValuableToken]) {
        fiatMoneySymbolLabel.text = Currency.current.symbol
        
        let valuableTokens = tokens.filter { token in
            token.decimalUSDBalance > 0
        }.sorted { one, another in
            one.decimalUSDBalance > another.decimalUSDBalance
        }
        let totalUSDBalance: Decimal = valuableTokens.map(\.decimalUSDBalance).reduce(0, +)
        let assetPortions: [AssetPortion] = {
            var portions: [AssetPortion] = []
            var subsequentTokensAsOthers = false
            for token in valuableTokens {
                let percent = NSDecimalNumber(decimal: token.decimalUSDBalance / totalUSDBalance)
                    .rounding(accordingToBehavior: NSDecimalNumberHandler.percentRoundingHandler)
                    .decimalValue
                let new = AssetPortion(symbol: token.symbol, percent: percent)
                portions.append(new)
                if portions.count == 3 || (portions.count == 2 && percent < 0.01) {
                    subsequentTokensAsOthers = true
                    break
                }
            }
            if subsequentTokensAsOthers {
                let percentWithoutLast = portions.prefix(portions.count - 1)
                    .map(\.percent)
                    .reduce(0, +)
                portions[portions.count - 1].percent = 1 - percentWithoutLast
                portions[portions.count - 1].symbol = R.string.localizable.other()
            }
            return portions
        }()
        let usdBalanceIsMoreThanZero = totalUSDBalance > 0
        fiatMoneyValueLabel.text = if totalUSDBalance.isZero {
            zeroWith2Fractions
        } else {
            CurrencyFormatter.localizedString(
                from: totalUSDBalance * Currency.current.decimalRate,
                format: .fiatMoney,
                sign: .never
            )
        }
        assetChartWrapperView.isHidden = !usdBalanceIsMoreThanZero
        switch assetPortions.count {
        case 0:
            break
        case 1:
            leftAssetWrapperView.isHidden = true
            middleAssetWrapperView.isHidden = false
            rightAssetWrapperView.isHidden = true
            middleAssetSymbolLabel.text = assetPortions[0].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: 1)
        case 2:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = true
            rightAssetWrapperView.isHidden = false
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: assetPortions[0].percent)
            rightAssetSymbolLabel.text = assetPortions[1].symbol
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: assetPortions[1].percent)
        default:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = false
            rightAssetWrapperView.isHidden = false
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: assetPortions[0].percent)
            middleAssetSymbolLabel.text = assetPortions[1].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: assetPortions[1].percent)
            rightAssetSymbolLabel.text = assetPortions[2].symbol
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: assetPortions[2].percent)
        }
        assetChartView.proportions = assetPortions.map { portion in
            NSDecimalNumber(decimal: portion.percent).doubleValue
        }
    }
    
    func reloadPendingDeposits(tokens: [MixinToken], snapshots: [SafeSnapshot]) {
        if tokens.isEmpty || snapshots.isEmpty {
            pendingDepositView.isHidden = true
            contentViewBottomConstraint.constant = 17
        } else {
            pendingDepositView.isHidden = false
            contentViewBottomConstraint.constant = 10
            for iconView in pendingDepositIconStackView.arrangedSubviews {
                iconView.removeFromSuperview()
            }
            let iconViewCount = if tokens.count <= maxPendingDepositTokenIconCount {
                tokens.count
            } else {
                maxPendingDepositTokenIconCount - 1
            }
            var iconViews: [UIView] = tokens.prefix(iconViewCount).map { token in
                let view = StackedIconWrapperView<PlainTokenIconView>()
                view.backgroundColor = .clear
                pendingDepositIconStackView.addArrangedSubview(view)
                view.iconView.setIcon(token: token)
                return view
            }
            if tokens.count > maxPendingDepositTokenIconCount {
                let view = StackedIconWrapperView<UILabel>()
                view.backgroundColor = .clear
                pendingDepositIconStackView.addArrangedSubview(view)
                view.iconView.backgroundColor = R.color.background_tag()
                view.iconView.textColor = R.color.text_tertiary()
                view.iconView.font = .systemFont(ofSize: 8)
                view.iconView.textAlignment = .center
                view.iconView.minimumScaleFactor = 0.1
                view.iconView.text = "+\(tokens.count - iconViewCount)"
                view.iconView.layer.cornerRadius = 7
                view.iconView.layer.masksToBounds = true
                iconViews.append(view)
            }
            for i in 0..<iconViews.count {
                let iconView = iconViews[i]
                let multiplier = i == iconViews.count - 1 ? 1 : 0.5
                iconView.snp.makeConstraints { make in
                    make.width.equalTo(iconView.snp.height)
                        .multipliedBy(multiplier)
                }
            }
            if snapshots.count == 1,
               let amount = Decimal(string: snapshots[0].amount, locale: .enUSPOSIX),
               let token = tokens.first(where: { $0.assetID == snapshots[0].assetID })
            {
                let item = CurrencyFormatter.localizedString(
                    from: amount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(token.symbol)
                )
                pendingDepositLabel.text = R.string.localizable.deposit_pending_confirmation(item)
            } else {
                pendingDepositLabel.text = R.string.localizable.deposits_pending_confirmation(snapshots.count)
            }
        }
    }
    
}

extension WalletHeaderView {
    
    private struct AssetPortion {
        var symbol: String
        var percent: Decimal
    }
    
    private func layoutSnowfallLayer(_ layer: CAEmitterLayer) {
        layer.frame = bounds
        layer.emitterPosition = CGPoint(x: layer.bounds.width / 2, y: -20)
        layer.emitterSize = CGSize(width: layer.bounds.width, height: 0)
    }
    
}

fileprivate extension Double {
    func roundTo(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
