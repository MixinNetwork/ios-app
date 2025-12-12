import UIKit

final class WalletSummarySafeIntroductionCell: UICollectionViewCell {
    
    enum Content {
        case upgradePlan
        case createSafe
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var actionView: PillActionView!
    @IBOutlet weak var actionIndicatorImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 13
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        actionView.layer.cornerRadius = 12
        actionView.layer.masksToBounds = true
    }
    
    func load(content: Content) {
        switch content {
        case .upgradePlan:
            titleLabel.text = R.string.localizable.upgrade_plan()
            descriptionLabel.text = R.string.localizable.upgrade_safe_description()
            actionView.backgroundColor = R.color.background_quaternary()
            actionView.actions = [
                .init(title: R.string.localizable.upgrade(), style: .vibrant),
                .init(title: R.string.localizable.learn_more()),
            ]
            actionIndicatorImageView.tintColor = UIColor(displayP3RgbValue: 0x999999)
        case .createSafe:
            titleLabel.text = R.string.localizable.create_safe()
            descriptionLabel.text = R.string.localizable.create_safe_description()
            actionView.backgroundColor = R.color.theme()
            actionView.actions = [
                .init(title: R.string.localizable.guideline(), style: .filled),
            ]
            actionIndicatorImageView.tintColor = .white
        }
    }
    
}
