import UIKit
import MixinServices

class WalletHeaderView: InfiniteTopView {
    
    @IBOutlet weak var fiatMoneySymbolLabel: UILabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    @IBOutlet weak var btcValueLabel: UILabel!
    
    @IBOutlet weak var assetChartWrapperView: UIView!
    @IBOutlet weak var assetChartView: BarChartView!
    
    @IBOutlet weak var leftAssetWrapperView: UIView!
    @IBOutlet weak var leftAssetSymbolLabel: UILabel!
    @IBOutlet weak var leftAssetPercentLabel: UILabel!
    
    @IBOutlet weak var middleAssetWrapperView: UIView!
    @IBOutlet weak var middleAssetSymbolLabel: UILabel!
    @IBOutlet weak var middleAssetPercentLabel: UILabel!
    
    @IBOutlet weak var rightAssetWrapperView: UIView!
    @IBOutlet weak var rightAssetSymbolLabel: UILabel!
    @IBOutlet weak var rightAssetPercentLabel: UILabel!
    
    var showSnowfallEffect = false {
        didSet {
            if showSnowfallEffect {
                if snowfallLayer.superlayer == nil {
                    layer.insertSublayer(snowfallLayer, at: 0)
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
    
    private lazy var snowfallLayer: CAEmitterLayer = {
        let cell = CAEmitterCell()
        cell.birthRate = 3
        cell.lifetime = 10
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
    
    private var contentHeight: CGFloat = 159
    
    private var snowflakeColor: CGColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.4).cgColor
        } else {
            return UIColor(displayP3RgbValue: 0x9CABE9, alpha: 0.4).cgColor
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: contentHeight)
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
    
    func render(assets: [AssetItem]) {
        fiatMoneySymbolLabel.text = Currency.current.symbol
        var assetPortions = [AssetPortion]()
        var btcTotalBalance: Double = 0
        let usdTotalBalance: Double = assets.map { $0.balance.doubleValue * $0.priceUsd.doubleValue }.reduce(0, +)
        var maxPortion = 3

        for asset in assets {
            let balance = asset.balance.doubleValue
            let usdBalance = balance * asset.priceUsd.doubleValue
            if usdBalance > 0 {
                let btcBalance = balance * asset.priceBtc.doubleValue
                btcTotalBalance += btcBalance
                if assetPortions.count < maxPortion {
                    let percent: Double = (usdBalance / usdTotalBalance).roundTo(places: 2)
                    let new = AssetPortion(symbol: asset.symbol, usdBalance: usdBalance, percent: percent)
                    assetPortions.append(new)
                    if assetPortions.count == 2 && percent < 0.01 {
                        maxPortion = 2
                    }
                } else {
                    assetPortions[assetPortions.count - 1].usdBalance += usdBalance
                    assetPortions[assetPortions.count - 1].symbol = R.string.localizable.other()
                }
            }
        }
        let usdBalanceIsMoreThanZero = usdTotalBalance > 0
        contentHeight = usdBalanceIsMoreThanZero ? 159 : 107
        fiatMoneyValueLabel.text = fiatMoneyBalanceRepresentation(usdBalance: usdTotalBalance)
        let btcValue = CurrencyFormatter.localizedString(from: btcTotalBalance, format: .pretty, sign: .never) ?? "0.00"
        let attributedBTCValue = NSAttributedString(string: btcValue, attributes: btcValueAttributes)
        btcValueLabel.attributedText = attributedBTCValue
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
            assetChartView.proportions = [1]
        case 2:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = true
            rightAssetWrapperView.isHidden = false
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: assetPortions[0].percent))
            rightAssetSymbolLabel.text = assetPortions[1].symbol
            assetPortions[1].percent = (1 - assetPortions[0].percent).roundTo(places: 2)
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: assetPortions[1].percent))
            assetChartView.proportions = assetPortions.map { $0.percent }
        default:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = false
            rightAssetWrapperView.isHidden = false
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: assetPortions[0].percent))
            middleAssetSymbolLabel.text = assetPortions[1].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: assetPortions[1].percent))
            rightAssetSymbolLabel.text = assetPortions[2].symbol
            assetPortions[2].percent = abs(1 - assetPortions[0].percent - assetPortions[1].percent).roundTo(places: 2)
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: assetPortions[2].percent))
            assetChartView.proportions = assetPortions.map { $0.percent }
        }
    }
    
}

extension WalletHeaderView {
    
    struct AssetPortion {
        var symbol: String
        var usdBalance: Double
        var percent: Double
    }
    
    private func fiatMoneyBalanceRepresentation(usdBalance: Double) -> String? {
        if usdBalance == 0 {
            return "0" + currentDecimalSeparator + "00"
        } else {
            return CurrencyFormatter.localizedString(from: usdBalance * Currency.current.rate,
                                                     format: .fiatMoney,
                                                     sign: .never)
        }
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
