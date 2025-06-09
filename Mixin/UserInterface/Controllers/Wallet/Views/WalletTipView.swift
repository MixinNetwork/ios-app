import UIKit

final class WalletTipView: UIView {
    
    enum Content {
        case privacy
        case classic
    }
    
    protocol Delegate: AnyObject {
        func walletTipViewWantsToClose(_ view: WalletTipView)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var learnMoreButton: UIButton!
    
    weak var delegate: Delegate?
    
    var content: Content? = nil {
        didSet {
            switch content {
            case .privacy:
                imageView.image = R.image.privacy_wallet_tip()
                titleLabel.text = R.string.localizable.privacy_wallet_tip_title()
                descriptionLabel.text = R.string.localizable.privacy_wallet_tip_description()
            case .classic:
                imageView.image = R.image.classic_wallet_tip()
                titleLabel.text = R.string.localizable.classic_wallet_tip_title()
                descriptionLabel.text = R.string.localizable.classic_wallet_tip_description()
            case nil:
                break
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 13
        layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        let attributes: AttributeContainer = {
            var container = AttributeContainer()
            container.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14, weight: .medium))
            container.foregroundColor = R.color.theme()
            return container
        }()
        learnMoreButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.learn_more(),
            attributes: attributes
        )
    }
    
    @IBAction func close(_ sender: Any) {
        delegate?.walletTipViewWantsToClose(self)
    }
    
    @IBAction func learnMore(_ sender: Any) {
        guard let content else {
            return
        }
        let string = switch content {
        case .privacy:
            R.string.localizable.url_privacy_wallet()
        case .classic:
            R.string.localizable.url_classic_wallet()
        }
        guard let url = URL(string: string) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
}
