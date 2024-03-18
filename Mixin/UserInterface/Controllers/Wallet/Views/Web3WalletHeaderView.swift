import UIKit

final class Web3WalletHeaderView: UIView {
    
    protocol Delegate: AnyObject {
        func web3WalletHeaderViewRequestToCreateAccount(_ view: Web3WalletHeaderView)
        func web3WalletHeaderViewRequestToCopyAddress(_ view: Web3WalletHeaderView)
    }
    
    private enum Action {
        case createAccount
        case copyAddress
    }
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    weak var delegate: Delegate?
    
    private let backgroundLayer = CAGradientLayer()
    private let addressPrefixCount = 8
    private let addressSuffixCount = 6
    
    private var action: Action?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundLayer.locations = [0, 1]
        backgroundLayer.startPoint = CGPoint(x: 0.25, y: 0.5)
        backgroundLayer.endPoint = CGPoint(x: 0.75, y: 0.5)
        backgroundLayer.cornerRadius = 16
        backgroundLayer.masksToBounds = true
        layer.insertSublayer(backgroundLayer, at: 0)
        setNeedsLayout()
        updateBackgroundColors(with: traitCollection)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundLayer.frame.size = bounds.insetBy(dx: 20, dy: 10).size
        backgroundLayer.position = center
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBackgroundColors(with: traitCollection)
    }
    
    @IBAction func requestAction(_ sender: Any) {
        switch action {
        case .createAccount:
            delegate?.web3WalletHeaderViewRequestToCreateAccount(self)
        case .copyAddress:
            delegate?.web3WalletHeaderViewRequestToCopyAddress(self)
        case nil:
            break
        }
    }
    
    func showCreateAccount(chain: WalletConnectService.Chain) {
        iconImageView.image = icon(of: chain)
        
        topLabel.font = .systemFont(ofSize: 18, weight: .medium)
        topLabel.textColor = R.color.text()
        topLabel.text = chain.name + " Account"
        
        bottomLabel.font = .systemFont(ofSize: 14)
        bottomLabel.textColor = R.color.text_tertiary()
        bottomLabel.text = "Access dapps and DeFi projects."
        
        button.setTitle(R.string.localizable.create(), for: .normal)
        action = .createAccount
    }
    
    func showCopyAddress(chain: WalletConnectService.Chain) {
        iconImageView.image = icon(of: chain)
        
        topLabel.font = .systemFont(ofSize: 18, weight: .medium)
        topLabel.textColor = R.color.text()
        topLabel.text = chain.name + " Account"
        
        bottomLabel.font = .systemFont(ofSize: 14)
        bottomLabel.textColor = R.color.text_tertiary()
        bottomLabel.text = "Access dapps and DeFi projects."
        
        button.setTitle("Copy Address", for: .normal)
        action = .copyAddress
    }
    
    private func updateBackgroundColors(with traitCollection: UITraitCollection) {
        switch traitCollection.userInterfaceStyle {
        case .dark:
            iconImageView.alpha = 0.04
            backgroundLayer.colors = [
                UIColor(displayP3RgbValue: 0x40444A).cgColor,
                UIColor(displayP3RgbValue: 0x3B3F44).cgColor,
            ]
        case .light, .unspecified:
            fallthrough
        @unknown default:
            iconImageView.alpha = 0.7
            backgroundLayer.colors = [
                UIColor(displayP3RgbValue: 0xF6F7FA).cgColor,
                UIColor(displayP3RgbValue: 0xEEF0F3).cgColor,
            ]
        }
    }
    
    private func icon(of chain: WalletConnectService.Chain) -> UIImage? {
        switch chain {
        case .ethereum:
            R.image.explore.web3_icon_eth()
        case .polygon:
            R.image.explore.web3_icon_matic()
        case .bnbSmartChain:
            R.image.explore.web3_icon_bsc()
        default:
            nil
        }
    }
    
}
