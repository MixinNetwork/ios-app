import UIKit
import MixinServices

class WalletHeaderView: InfiniteTopView {
    
    @IBOutlet weak var fiatMoneySymbolLabel: UILabel!
    @IBOutlet weak var fiatMoneyValueLabel: InsetLabel!
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
    
    private var contentHeight: CGFloat = 159
    private let btcValueAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.dinCondensedBold(ofSize: 14).scaled(),
        .kern: 0.7
    ]
    
    override func awakeFromNib() {
        super.awakeFromNib()
        fiatMoneyValueLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: contentHeight)
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
                    assetPortions[assetPortions.count - 1].symbol = Localized.WALLET_SYMBOL_OTHER
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
    
}

fileprivate extension Double {
    func roundTo(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
