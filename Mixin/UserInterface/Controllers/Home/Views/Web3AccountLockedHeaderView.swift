import UIKit

final class Web3AccountLockedHeaderView: UIView {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    private let backgroundLayer = CAGradientLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
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
    
    func showUnlockAccount(chain: Web3Chain) {
        iconImageView.image = icon(of: chain)
        
        topLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .medium),
                         adjustForContentSize: true)
        topLabel.textColor = R.color.text()
        topLabel.text = R.string.localizable.web3_account_network(chain.name)
        
        bottomLabel.setFont(scaledFor: .systemFont(ofSize: 14),
                            adjustForContentSize: true)
        bottomLabel.textColor = R.color.text_tertiary()
        bottomLabel.text = R.string.localizable.access_dapps_defi_projects()
        
        UIView.performWithoutAnimation {
            button.setTitle(R.string.localizable.unlock(), for: .normal)
            button.layoutIfNeeded()
        }
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
    
    private func icon(of chain: Web3Chain) -> UIImage? {
        switch chain {
        case .ethereum:
            R.image.explore.web3_icon_eth()
        default:
            nil
        }
    }
    
}
