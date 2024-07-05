import UIKit
import MixinServices

final class Web3AccountHeaderView: Web3HeaderView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var accountNameLabel: UILabel!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    
    private(set) weak var swapButton: UIButton?
    private(set) weak var browseButton: UIButton!
    private(set) weak var moreButton: UIButton!
    
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
    
    func addTarget(_ target: Any, send: Selector, receive: Selector, browse: Selector, more: Selector) {
        super.addTarget(target, send: send, receive: receive)
        
        browseButton.removeTarget(nil, action: nil, for: .allEvents)
        browseButton.addTarget(target, action: browse, for: .touchUpInside)
        
        moreButton.removeTarget(nil, action: nil, for: .allEvents)
        moreButton.addTarget(target, action: more, for: .touchUpInside)
    }
    
    func addSwapButton(_ target: Any, action: Selector) {
        guard swapButton == nil else {
            return
        }
        let (wrapper, button) = makeActionView(title: R.string.localizable.swap(),
                                               icon: R.image.web3_action_swap()!)
        actionStackView.insertArrangedSubview(wrapper, at: 2)
        button.addTarget(target, action: action, for: .touchUpInside)
        swapButton = button
    }
    
    func enableSwapButton() {
        guard swapButton != nil else {
            return
        }
        enable(wrapper: actionStackView.arrangedSubviews[2])
    }
    
    func disableSwapButton() {
        guard swapButton != nil else {
            return
        }
        disable(wrapper: actionStackView.arrangedSubviews[2])
    }
    
    func enableSendButton() {
        enable(wrapper: actionStackView.arrangedSubviews[0])
    }
    
    func disableSendButton() {
        disable(wrapper: actionStackView.arrangedSubviews[0])
    }
    
    private func enable(wrapper: UIView) {
        wrapper.alpha = 1
        wrapper.isUserInteractionEnabled = true
    }
    
    private func disable(wrapper: UIView) {
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
