import UIKit
import SDWebImage
import MixinServices

final class MembershipPlanSelectorCell: UICollectionViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    
    override var isSelected: Bool {
        didSet {
            nameLabel.textColor = isSelected ? R.color.theme()! : R.color.text()!
            setBorderColor(isSelected: isSelected, traitCollection: traitCollection)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        contentView.layer.cornerRadius = contentView.bounds.height / 2
        setBorderColor(isSelected: false, traitCollection: traitCollection)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setBorderColor(isSelected: isSelected, traitCollection: traitCollection)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.cornerRadius = contentView.bounds.height / 2
    }
    
    func load(plan: SafeMembership.Plan) {
        switch plan {
        case .basic:
            nameLabel.text = R.string.localizable.membership_advance()
            iconImageView.image = R.image.membership_advance()
        case .standard:
            nameLabel.text = R.string.localizable.membership_elite()
            iconImageView.image = R.image.membership_elite()
        case .premium:
            nameLabel.text = R.string.localizable.membership_prosperity()
            iconImageView.image = UserBadgeIcon.prosperityImage
        }
    }
    
    private func setBorderColor(isSelected: Bool, traitCollection: UITraitCollection) {
        let color = isSelected ? R.color.theme()! : R.color.outline_primary()!
        contentView.layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
    }
    
}
