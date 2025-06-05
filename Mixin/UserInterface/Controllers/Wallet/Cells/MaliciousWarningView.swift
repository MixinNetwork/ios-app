import UIKit

final class MaliciousWarningView: UIView {
    
    enum Content {
        case token
        case transaction
    }
    
    @IBOutlet weak var label: UILabel!
    
    var content: Content? {
        didSet {
            label.text = switch content {
            case .token:
                R.string.localizable.reputation_spam_token_warning()
            case .transaction:
                R.string.localizable.reputation_spam_transaction_warning()
            case nil:
                nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = R.color.red()?.withAlphaComponent(0.2)
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
}
