import UIKit
import SafariServices
import MixinServices

final class WalletTipCell: UICollectionViewCell {
    
    enum Content: CaseIterable {
        case safe
        case privacy
        case classic
        case importedWalletSafety
    }
    
    protocol Delegate: AnyObject {
        func walletTipCell(_ cell: WalletTipCell, requestToLearnMore url: URL)
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
            case .safe:
                imageView.image = R.image.safe_wallet_introduction()
                titleLabel.text = R.string.localizable.whats_safe_wallet()
                descriptionLabel.text = R.string.localizable.safe_wallet_description()
            case .importedWalletSafety:
                imageView.image = R.image.free()
                titleLabel.text = R.string.localizable.free_transfers_between_wallets_title()
                descriptionLabel.text = R.string.localizable.free_transfers_between_wallets_description()
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
        switch content {
        case .privacy:
            AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip = true
        case .classic:
            AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip = true
        case .safe:
            AppGroupUserDefaults.Wallet.hasViewedSafeWalletTip = true
        case .importedWalletSafety:
            BadgeManager.shared.setHasViewed(identifier: .freeTransfer)
        case .none:
            break
        }
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
        case .safe:
            R.string.localizable.safe_learn_more_url()
        case .importedWalletSafety:
            R.string.localizable.url_cross_wallet_transaction_free()
        }
        guard let url = URL(string: string) else {
            return
        }
        delegate?.walletTipCell(self, requestToLearnMore: url)
    }
    
}
