import UIKit

final class ExploreRecentSearchCell: UICollectionViewCell {
    
    @IBOutlet weak var iconWrapperView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: MarketColoredLabel!
    
    private weak var plainIconView: PlainTokenIconView?
    private weak var tokenIconView: BadgeIconView?
    private weak var avatarImageView: AvatarImageView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        updateBorderColor()
        contentView.snp.makeConstraints { make in
            // XXX: Otherwise it breaks out the layout width
            make.width.lessThanOrEqualTo(UIScreen.main.bounds.width - 40)
        }
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.cornerRadius = contentView.bounds.height / 2
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        plainIconView?.prepareForReuse()
        tokenIconView?.prepareForReuse()
        avatarImageView?.prepareForReuse()
    }
    
    func setImage(_ setter: (PlainTokenIconView) -> Void) {
        let iconView: PlainTokenIconView
        if let view = plainIconView {
            view.isHidden = false
            iconView = view
        } else {
            iconView = PlainTokenIconView(frame: iconWrapperView.bounds)
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeEdgesEqualToSuperview()
            self.plainIconView = iconView
        }
        setter(iconView)
        tokenIconView?.isHidden = true
        avatarImageView?.isHidden = true
    }
    
    func setBadgeIcon(_ setter: (BadgeIconView) -> Void) {
        let iconView: BadgeIconView
        if let view = tokenIconView {
            view.isHidden = false
            iconView = view
        } else {
            iconView = BadgeIconView(frame: iconWrapperView.bounds)
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeEdgesEqualToSuperview()
            self.tokenIconView = iconView
        }
        setter(iconView)
        plainIconView?.isHidden = true
        avatarImageView?.isHidden = true
    }
    
    func setAvatar(_ setter: (AvatarImageView) -> Void) {
        let imageView: AvatarImageView
        if let view = avatarImageView {
            view.isHidden = false
            imageView = view
        } else {
            imageView = AvatarImageView(frame: iconWrapperView.bounds)
            iconWrapperView.addSubview(imageView)
            imageView.snp.makeEdgesEqualToSuperview()
            self.avatarImageView = imageView
        }
        setter(imageView)
        plainIconView?.isHidden = true
        tokenIconView?.isHidden = true
    }
    
    private func updateBorderColor() {
        contentView.layer.borderColor = switch traitCollection.userInterfaceStyle {
        case .dark:
            UIColor.white.withAlphaComponent(0.06).cgColor
        case .light, .unspecified:
            UIColor.black.withAlphaComponent(0.06).cgColor
        @unknown default:
            UIColor.black.withAlphaComponent(0.06).cgColor
        }
    }
    
}
