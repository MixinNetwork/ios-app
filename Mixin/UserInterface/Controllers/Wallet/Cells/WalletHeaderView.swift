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
        var usdTotalBalance: Double = 0
        for asset in assets {
            let balance = asset.balance.doubleValue
            let usdBalance = balance * asset.priceUsd.doubleValue
            if usdBalance > 0 {
                let btcBalance = balance * asset.priceBtc.doubleValue
                btcTotalBalance += btcBalance
                usdTotalBalance += usdBalance
                if assetPortions.count < 3 {
                    let new = AssetPortion(symbol: asset.symbol, usdBalance: usdBalance)
                    assetPortions.append(new)
                } else {
                    assetPortions[2].usdBalance += usdBalance
                    assetPortions[2].symbol = Localized.WALLET_SYMBOL_OTHER
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
            let leftPercent = assetPortions[0].usdBalance / usdTotalBalance
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: leftPercent))
            let rightPercent = 1 - leftPercent
            rightAssetSymbolLabel.text = assetPortions[1].symbol
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: rightPercent))
            assetChartView.proportions = [leftPercent, rightPercent]
        default:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = false
            rightAssetWrapperView.isHidden = false
            let leftPercent = assetPortions[0].usdBalance / usdTotalBalance
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: leftPercent))
            let middlePercent = assetPortions[1].usdBalance / usdTotalBalance
            middleAssetSymbolLabel.text = assetPortions[1].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: middlePercent))
            let rightPercent = 1 - leftPercent - middlePercent
            rightAssetSymbolLabel.text = assetPortions[2].symbol
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: rightPercent))
            assetChartView.proportions = [leftPercent, middlePercent, rightPercent]
        }
    }
    
}

extension WalletHeaderView {
    
    struct AssetPortion {
        var symbol: String
        var usdBalance: Double
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
