import UIKit

final class WalletTipCell: UICollectionViewCell {
    
    enum Content {
        case privacy
        case classic
    }
    
    protocol Delegate: AnyObject {
        func walletTipCellWantsToClose(_ cell: WalletTipCell)
        func walletTipCell(_ cell: WalletTipCell, wantsToLearnMoreAbout content: Content)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var learnMoreButton: UIButton!
    
    var content: Content? = nil {
        didSet {
            load(content: content)
        }
    }
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 13
        contentView.layer.masksToBounds = true
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        descriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
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
        delegate?.walletTipCellWantsToClose(self)
    }
    
    @IBAction func learnMore(_ sender: Any) {
        if let content {
            delegate?.walletTipCell(self, wantsToLearnMoreAbout: content)
        }
    }
    
    private func load(content: Content?) {
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
