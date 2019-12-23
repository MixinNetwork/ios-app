import UIKit
import MixinServices

class CurrencyCell: UITableViewCell {
    
    @IBOutlet weak var checkmarkView: CheckmarkView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var codeLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    
    func render(currency: Currency) {
        iconImageView.image = currency.icon
        codeLabel.text = currency.code
        symbolLabel.text = "(" + currency.symbol + ")"
    }
    
}
