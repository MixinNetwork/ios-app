import UIKit

final class MaliciousWarningView: UIView {
    
    enum Content {
        case token
        case transaction
    }
    
    @IBOutlet weak var imageView: UIImageView!
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
        imageView.image = R.image.web3_reputation_bad()!.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = R.color.error_red()
        backgroundColor = R.color.red()!.withAlphaComponent(0.2)
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
}
