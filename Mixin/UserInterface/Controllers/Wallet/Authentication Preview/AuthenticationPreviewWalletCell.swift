import UIKit
import MixinServices

final class AuthenticationPreviewWalletCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        captionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func load(wallet: Wallet, threshold: Int32?) {
        switch wallet {
        case .privacy:
            captionLabel.text = if let threshold {
                R.string.localizable.multisig_sender().uppercased()
            } else {
                R.string.localizable.sender().uppercased()
            }
            nameLabel.text = R.string.localizable.privacy_wallet()
        default:
            assertionFailure()
        }
    }
    
}
