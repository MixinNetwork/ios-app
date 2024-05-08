import UIKit
import MixinServices

final class Web3AccountHeaderView: Web3HeaderView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var accountNameLabel: UILabel!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        symbolLabel.text = Currency.current.symbol
        amountLabel.font = .condensed(size: 40)
        amountLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        amountLabel.text = "0" + currentDecimalSeparator + "00"
        browseButton = addAction(title: R.string.localizable.browser(),
                                 icon: R.image.web3_action_browser()!)
        moreButton = addAction(title: R.string.localizable.more(),
                               icon: R.image.web3_action_more()!)
    }
    
    func setNetworkName(_ name: String) {
        accountNameLabel.text = R.string.localizable.web3_account_network(name)
    }
    
    func enableSendButton() {
        let wrapper = actionStackView.arrangedSubviews[0]
        wrapper.alpha = 1
        wrapper.isUserInteractionEnabled = true
    }
    
    func disableSendButton() {
        let wrapper = actionStackView.arrangedSubviews[0]
        switch traitCollection.userInterfaceStyle {
        case .dark:
            wrapper.alpha = 0.45
        case .unspecified, .light:
            fallthrough
        @unknown default:
            wrapper.alpha = 0.3
        }
        wrapper.isUserInteractionEnabled = false
    }
    
}
