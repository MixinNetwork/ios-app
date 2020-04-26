import UIKit
import MixinServices

class CurrencyCell: UITableViewCell {
    
    @IBOutlet weak var checkmarkImageView: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var codeLabel: UILabel!
    
    func render(currency: Currency) {
        iconImageView.image = currency.icon
        codeLabel.text = currency.code + " (" + currency.symbol + ")"
    }
    
}
