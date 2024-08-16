import UIKit
import MixinServices

final class TokenMarketCell: UITableViewCell {
    
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var chartView: ChartView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        priceLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .medium),
                           adjustForContentSize: true)
        changeLabel.setFont(scaledFor: .systemFont(ofSize: 14),
                            adjustForContentSize: true)
    }
    
    func reloadData(token: TokenItem, points: [ChartView.Point]?) {
        if let points, points.count >= 2 {
            let firstValue = points[0].value
            let lastValue = points[points.count - 1].value
            priceLabel.text = CurrencyFormatter.localizedString(
                from: lastValue * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
                sign: .never,
                symbol: .currencySymbol
            )
            let change = (lastValue - firstValue) / firstValue
            changeLabel.text = NumberFormatter.percentage.string(decimal: change)
            changeLabel.textColor = change >= 0 ? .priceRising : .priceFalling
            chartView.points = points
        } else {
            priceLabel.text = token.localizedFiatMoneyPrice
            changeLabel.text = NumberFormatter.percentage.string(decimal: token.decimalUSDChange)
            changeLabel.textColor = token.decimalUSDChange >= 0 ? .priceRising : .priceFalling
            chartView.points = []
        }
    }
    
}
