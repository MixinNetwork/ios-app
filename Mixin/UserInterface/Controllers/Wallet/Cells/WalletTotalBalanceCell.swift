import UIKit

class WalletTotalBalanceCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_total_balance"
    static let cellHeight: CGFloat = 284

    @IBOutlet weak var pieView: PieChartView!
    @IBOutlet weak var indicatorStackView: UIStackView!
    
    @IBOutlet weak var leftAssetView: UIView!
    @IBOutlet weak var leftAssetLabel: UILabel!
    @IBOutlet weak var leftPercentLabel: UILabel!
    
    @IBOutlet weak var middleAssetView: UIView!
    @IBOutlet weak var middleAssetLabel: UILabel!
    @IBOutlet weak var middlePercentLabel: UILabel!
    
    @IBOutlet weak var rightAssetView: UIView!
    @IBOutlet weak var rightAssetLabel: UILabel!
    @IBOutlet weak var rightPercentLabel: UILabel!

    @IBOutlet weak var btcBalanceLabel: UILabel!
    @IBOutlet weak var usdBalanceLabel: UILabel!
    
    private let colors = [UIColor(rgbValue: 0x005EE4), UIColor(rgbValue: 0x3387FF), UIColor(rgbValue: 0x70BEFF)]
    
    func render(assets: [AssetItem]) {
        var segments = [PieSegment]()
        var totalPriceBalance: Double = 0
        var btcTotalBalance: Double = 0
        var usdTotalBalance: Double = 0
        for asset in assets {
            let balance = asset.balance.doubleValue
            let priceBalance = balance * asset.priceUsd.doubleValue
            if priceBalance > 0 {
                btcTotalBalance += balance * asset.priceBtc.doubleValue
                usdTotalBalance += balance * asset.priceUsd.doubleValue
                totalPriceBalance += priceBalance
                if segments.count < 3 {
                    segments.append(PieSegment(color: colors[segments.count], value: priceBalance, symbol: asset.symbol))
                } else {
                    segments[2].value += priceBalance
                    segments[2].symbol = Localized.WALLET_SYMBOL_OTHER
                }
            }
        }

        btcBalanceLabel.text = String(format: "%@ BTC", btcTotalBalance.formatSimpleBalance())
        usdBalanceLabel.text = String(format: "%@ USD", usdTotalBalance.toFormatLegalTender())

        indicatorStackView.isHidden = segments.count == 0
        switch segments.count {
        case 0:
            leftAssetView.isHidden = true
            middleAssetView.isHidden = true
            rightAssetView.isHidden = true
            segments.append(PieSegment(color: UIColor.groupTableViewBackground, value: 1, symbol: ""))
        case 1:
            leftAssetView.isHidden = true
            middleAssetView.isHidden = false
            rightAssetView.isHidden = true
            middleAssetLabel.text = segments[0].symbol
            middlePercentLabel.text = "100%"
        case 2:
            leftAssetView.isHidden = false
            middleAssetView.isHidden = true
            rightAssetView.isHidden = false
            let leftPercent = Int((segments[0].value / totalPriceBalance * 100).rounded(.down))
            leftAssetLabel.text = segments[0].symbol
            leftPercentLabel.text = "\(leftPercent)%"
            rightAssetLabel.text = segments[1].symbol
            rightPercentLabel.text = "\(100 - leftPercent)%"
        default:
            leftAssetView.isHidden = false
            middleAssetView.isHidden = false
            rightAssetView.isHidden = false

            let leftPercent = Int((segments[0].value / totalPriceBalance * 100).rounded(.down))
            leftAssetLabel.text = segments[0].symbol
            leftPercentLabel.text = "\(leftPercent)%"

            let middlePercent = Int((segments[1].value / totalPriceBalance * 100).rounded(.up))
            middleAssetLabel.text = segments[1].symbol
            middlePercentLabel.text = "\(middlePercent)%"
            rightAssetLabel.text = segments[2].symbol
            rightPercentLabel.text = "\(100 - leftPercent - middlePercent)%"
        }
        pieView.segments = segments
    }
}

