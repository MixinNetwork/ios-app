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
    
    private let btcValueAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.dinCondensedBold(ofSize: 14).scaled(),
        .kern: 0.7
    ]
    
    private let percentRounding = NSDecimalNumberHandler(roundingMode: .plain,
                                                         scale: 2,
                                                         raiseOnExactness: false,
                                                         raiseOnOverflow: false,
                                                         raiseOnUnderflow: false,
                                                         raiseOnDivideByZero: false)
    
    private var contentHeight: CGFloat = 159
    
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
        var btcTotalBalance: Decimal = 0
        let usdTotalBalance: Decimal = assets
            .map { $0.decimalBalance * $0.decimalUSDPrice }
            .reduce(0, +)
        var maxPortion = 3
        for asset in assets {
            let balance = asset.decimalBalance
            let usdBalance = balance * asset.decimalUSDPrice
            if usdBalance > 0 {
                let btcBalance = balance * asset.decimalBTCPrice
                btcTotalBalance += btcBalance
                if assetPortions.count < maxPortion {
                    let percent = ((usdBalance / usdTotalBalance) as NSDecimalNumber)
                        .rounding(accordingToBehavior: percentRounding) as Decimal
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
        let btcValue = CurrencyFormatter.localizedString(from: btcTotalBalance, format: .pretty, sign: .never)
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
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: assetPortions[0].percent as NSDecimalNumber)
            rightAssetSymbolLabel.text = assetPortions[1].symbol
            assetPortions[1].percent = (1 - assetPortions[0].percent as NSDecimalNumber)
                .rounding(accordingToBehavior: percentRounding) as Decimal
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: assetPortions[1].percent as NSDecimalNumber)
            assetChartView.proportions = assetPortions.map { $0.percent.doubleValue }
        default:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = false
            rightAssetWrapperView.isHidden = false
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: assetPortions[0].percent as NSDecimalNumber)
            middleAssetSymbolLabel.text = assetPortions[1].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: assetPortions[1].percent as NSDecimalNumber)
            rightAssetSymbolLabel.text = assetPortions[2].symbol
            assetPortions[2].percent = (abs(1 - assetPortions[0].percent - assetPortions[1].percent) as NSDecimalNumber)
                .rounding(accordingToBehavior: percentRounding) as Decimal
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(from: assetPortions[2].percent as NSDecimalNumber)
            assetChartView.proportions = assetPortions.map { $0.percent.doubleValue }
        }
    }
    
}

extension WalletHeaderView {
    
    struct AssetPortion {
        var symbol: String
        var usdBalance: Decimal
        var percent: Decimal
    }
    
    private func fiatMoneyBalanceRepresentation(usdBalance: Decimal) -> String? {
        if usdBalance == 0 {
            return zeroFiatMoneyRepresentation
        } else {
            return CurrencyFormatter.localizedString(from: usdBalance * Currency.current.rate,
                                                     format: .fiatMoney,
                                                     sign: .never)
        }
    }
    
}
