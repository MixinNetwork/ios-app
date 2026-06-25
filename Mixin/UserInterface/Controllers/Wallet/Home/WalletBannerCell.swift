import UIKit

final class WalletBannerCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func walletBannerCell(_ cell: WalletBannerCell, requestPerformAction banner: WalletBanner, index: Int)
        func walletBannerCell(_ cell: WalletBannerCell, requestDismiss banner: WalletBanner)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    weak var delegate: Delegate?
    
    var banner: WalletBanner? {
        didSet {
            reload(banner: banner)
        }
    }
    
    private var actionButtons: [UIButton] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentStackView.setCustomSpacing(8, after: descriptionLabel)
        contentStackView.setCustomSpacing(0, after: actionStackView)
        imageView.layer.cornerRadius = 8
        imageView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
    }
    
    @IBAction func close(_ sender: Any) {
        guard let banner else {
            return
        }
        delegate?.walletBannerCell(self, requestDismiss: banner)
    }
    
    @objc private func requestAction(_ sender: UIButton) {
        guard let banner else {
            return
        }
        delegate?.walletBannerCell(self, requestPerformAction: banner, index: sender.tag)
    }
    
    private func reload(banner: WalletBanner?) {
        switch banner {
        case .embedded(let banner):
            switch banner {
            case .addWallet:
                imageView.image = R.image.wallet_tip_add()
                titleLabel.isHidden = true
                descriptionLabel.text = R.string.localizable.wallet_home_add_wallet_banner_title()
                descriptionLabel.isHidden = false
                actionStackView.isHidden = false
                reloadActionButtons(titles: [R.string.localizable.add_wallet()])
            }
        case .remote(let banner):
            imageView.sd_setImage(with: URL(string: banner.iconURL))
            if let actions = banner.actions, let title = actions.first?.label {
                // Title + Button
                titleLabel.isHidden = true
                descriptionLabel.text = banner.title
                descriptionLabel.isHidden = false
                reloadActionButtons(titles: [title])
                actionStackView.isHidden = false
            } else {
                // Title + Description
                titleLabel.text = banner.title
                titleLabel.isHidden = false
                descriptionLabel.text = banner.description
                descriptionLabel.isHidden = false
                actionStackView.isHidden = true
            }
        case .none:
            break
        }
    }
    
    private func reloadActionButtons(titles: [String]) {
        let diff = actionButtons.count - titles.count
        if diff > 0 {
            for button in actionButtons.suffix(diff) {
                button.removeFromSuperview()
            }
            actionButtons.removeLast(diff)
        } else if diff < 0 {
            for _ in (0 ..< -diff) {
                let button = UIButton(type: .system)
                actionButtons.append(button)
                actionStackView.addArrangedSubview(button)
                button.addTarget(self, action: #selector(requestAction(_:)), for: .touchUpInside)
            }
        }
        for (index, button) in actionButtons.enumerated() {
            button.tag = index
            button.configuration = actionButtonConfiguration(title: titles[index])
            if let label = button.titleLabel {
                label.adjustsFontForContentSizeCategory = true
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.5
            }
        }
    }
    
    private func actionButtonConfiguration(title: String) -> UIButton.Configuration {
        var config: UIButton.Configuration = .gray()
        config.baseForegroundColor = R.color.theme()
        config.baseBackgroundColor = R.color.background_quaternary()
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 3, trailing: 10)
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14, weight: .medium)
        )
        config.attributedTitle = AttributedString(title, attributes: attributes)
        return config
    }
    
}
