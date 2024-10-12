import UIKit
import MixinServices

final class TokenMarketCell: UITableViewCell {
    
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var chartView: ChartView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        priceLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .medium),
                           adjustForContentSize: true)
        changeLabel.setFont(scaledFor: .systemFont(ofSize: 14),
                            adjustForContentSize: true)
    }
    
}
