import UIKit
import MixinServices

final class WalletWatchingIndicatorView: UIView {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 18
    }
    
}
