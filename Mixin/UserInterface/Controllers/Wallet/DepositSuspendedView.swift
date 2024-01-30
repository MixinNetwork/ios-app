import UIKit
import MixinServices

final class DepositSuspendedView: UIView {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var contactSupportButton: RoundedButton!
    
    var symbol: String? {
        didSet {
            if let symbol {
                label.text = R.string.localizable.suspended_deposit(symbol, symbol)
            } else {
                label.text = nil
            }
        }
    }
    
}
