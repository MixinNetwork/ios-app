import UIKit

class WalletHeaderCell: UITableViewCell {
    
    @IBOutlet weak var usdValueLabel: InsetLabel!
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
    
    private let usdIntegerAttribute = [
        NSAttributedString.Key.font: UIFont(name: "DINCondensed-Bold", size: 40)!
    ]
    private let usdFractionAttribute = [
        NSAttributedString.Key.font: UIFont(name: "DINCondensed-Bold", size: 24)!
    ]
    private let btcValueAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "DINCondensed-Bold", size: 14)!,
        .kern: 0.7
    ]
    
    static func height(usdBalanceIsMoreThanZero: Bool) -> CGFloat {
        return usdBalanceIsMoreThanZero ? 187 : 135
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        usdValueLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
    }
    
    func render(assets: [AssetItem]) {
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
        
        usdValueLabel.attributedText = attributedString(usdBalance: usdTotalBalance)
        let btcValue = CurrencyFormatter.localizedString(from: btcTotalBalance, format: .pretty, sign: .never) ?? "0.00"
        let attributedBTCValue = NSAttributedString(string: btcValue, attributes: btcValueAttributes)
        btcValueLabel.attributedText = attributedBTCValue
        assetChartWrapperView.isHidden = usdTotalBalance <= 0
        switch assetPortions.count {
        case 0:
            break
        case 1:
            leftAssetWrapperView.isHidden = true
            middleAssetWrapperView.isHidden = false
            rightAssetWrapperView.isHidden = true
            middleAssetSymbolLabel.text = assetPortions[0].symbol
            middleAssetPercentLabel.text = WalletHeaderCell.percentageFormatter.string(from: 1)
            assetChartView.proportions = [1]
        case 2:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = true
            rightAssetWrapperView.isHidden = false
            let leftPercent = assetPortions[0].usdBalance / usdTotalBalance
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = WalletHeaderCell.percentageFormatter.string(from: NSNumber(value: leftPercent))
            let rightPercent = 1 - leftPercent
            rightAssetSymbolLabel.text = assetPortions[1].symbol
            rightAssetPercentLabel.text = WalletHeaderCell.percentageFormatter.string(from: NSNumber(value: rightPercent))
            assetChartView.proportions = [leftPercent, rightPercent]
        default:
            leftAssetWrapperView.isHidden = false
            middleAssetWrapperView.isHidden = false
            rightAssetWrapperView.isHidden = false
            let leftPercent = assetPortions[0].usdBalance / usdTotalBalance
            leftAssetSymbolLabel.text = assetPortions[0].symbol
            leftAssetPercentLabel.text = WalletHeaderCell.percentageFormatter.string(from: NSNumber(value: leftPercent))
            let middlePercent = assetPortions[1].usdBalance / usdTotalBalance
            middleAssetSymbolLabel.text = assetPortions[1].symbol
            middleAssetPercentLabel.text = WalletHeaderCell.percentageFormatter.string(from: NSNumber(value: middlePercent))
            let rightPercent = 1 - leftPercent - middlePercent
            rightAssetSymbolLabel.text = assetPortions[2].symbol
            rightAssetPercentLabel.text = WalletHeaderCell.percentageFormatter.string(from: NSNumber(value: rightPercent))
            assetChartView.proportions = [leftPercent, middlePercent, rightPercent]
        }
    }
    
}

extension WalletHeaderCell {
    
    struct AssetPortion {
        var symbol: String
        var usdBalance: Double
    }
    
    static let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimum = 0.01
        formatter.maximum = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .floor
        formatter.locale = .current
        return formatter
    }()
    
    private func attributedString(usdBalance: Double) -> NSAttributedString? {
        let zeroInteger = "0"
        let zeroFraction = "00"
        if usdBalance == 0 {
            let str = zeroInteger + currentDecimalSeparator + zeroFraction
            return NSAttributedString(string: str, attributes: usdIntegerAttribute)
        } else if let localizedUSDBalance = CurrencyFormatter.localizedString(from: usdBalance, format: .legalTender, sign: .never) {
            let components = localizedUSDBalance.components(separatedBy: currentDecimalSeparator)
            let integer = (components.first ?? zeroInteger) + currentDecimalSeparator
            let str = NSMutableAttributedString(string: integer, attributes: usdIntegerAttribute)
            let fraction = components.count < 2 ? zeroFraction : components[1]
            str.append(NSAttributedString(string: fraction, attributes: usdFractionAttribute))
            return str
        } else {
            return nil
        }
    }
    
}
