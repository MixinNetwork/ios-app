import UIKit

final class ExploreRecentSearchCell: UICollectionViewCell {
    
    enum Size {
        case large
        case medium
    }
    
    @IBOutlet weak var iconWrapperView: UIView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: MarketColoredLabel!
    
    @IBOutlet weak var iconWrapperTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconWrapperLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleStackViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleStackViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleStackViewBottomConstraint: NSLayoutConstraint!
    
    private weak var plainIconView: PlainTokenIconView?
    private weak var tokenIconView: BadgeIconView?
    private weak var avatarImageView: AvatarImageView?
    
    private var iconVerticalConstraints: [NSLayoutConstraint] {
        [iconWrapperTopConstraint, iconWrapperBottomConstraint]
    }
    
    private var titleVerticalConstraints: [NSLayoutConstraint] {
        [titleStackViewTopConstraint, titleStackViewBottomConstraint]
    }
    
    // When using UICollectionViewCompositionalLayout as the collection view layout,
    // if the item size uses an estimated width, the layout will call the cell’s
    // `systemLayoutSizeFitting(_:withHorizontalFittingPriority:verticalFittingPriority:)`
    // to obtain the size. If the size.width returned is too large, it can cause
    // the layout to crash. This behavior can be managed by setting this value.
    var maxCellWidth: CGFloat = 200
    
    var size: Size = .large {
        didSet {
            switch size {
            case .large:
                iconWrapperLeadingConstraint.constant = 6
                for constraint in iconVerticalConstraints {
                    constraint.constant = 6
                }
                for constraint in titleVerticalConstraints {
                    constraint.constant = 6
                }
                titleStackView.spacing = 2
                titleStackViewLeadingConstraint.constant = 8
                titleStackViewTrailingConstraint.constant = 18
            case .medium:
                iconWrapperLeadingConstraint.constant = 6
                for constraint in iconVerticalConstraints {
                    constraint.constant = 5
                }
                for constraint in titleVerticalConstraints {
                    constraint.constant = 4
                }
                titleStackView.spacing = 0
                titleStackViewLeadingConstraint.constant = 4
                titleStackViewTrailingConstraint.constant = 13
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        updateBorderColor()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.cornerRadius = contentView.bounds.height / 2
    }
    
    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        // The default implementation of `systemLayoutSizeFitting(_:withHorizontalFittingPriority:verticalFittingPriority:)`
        // seems unable to correctly handle constraints with Aspect Ratio, resulting in noticeably incorrect results.
        // This can cause panics with UICollectionViewCompositionalLayout.
        // To avoid this problem, the calculation process is handled manually.
        let titleSize = titleStackView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
        let height = titleSize.height + titleVerticalConstraints.reduce(0, { $0 + $1.constant })
        let iconDimension = height - iconVerticalConstraints.reduce(0, { $0 + $1.constant })
        let width = iconWrapperLeadingConstraint.constant
        + iconDimension
        + titleStackViewLeadingConstraint.constant
        + titleSize.width
        + titleStackViewTrailingConstraint.constant
        return CGSize(width: min(maxCellWidth, width), height: height)
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
            iconView.badgeIconDiameter = 11
            iconView.badgeOutlineWidth = 1
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
