import UIKit

final class PerpetualIntroductionCell: UICollectionViewCell {
    
    enum Guide {
        case manual
        case pro
    }
    
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var badgeLabel: InsetLabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        badgeLabel.text = R.string.localizable.trade_pro()
        badgeLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.clipsToBounds = true
        subtitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func configure(for guide: Guide) {
        switch guide {
        case .manual:
            iconView.image = R.image.perps_introduction()
            titleLabel.text = R.string.localizable.how_perps_works()
            badgeLabel.isHidden = true
            subtitleLabel.attributedText = nil
            subtitleLabel.text = R.string.localizable.learn_how_to_trade_perps()
        case .pro:
            iconView.image = R.image.perps_pro_introduction()
            titleLabel.text = R.string.localizable.trade_with_mixin_perps()
            badgeLabel.isHidden = false
            subtitleLabel.text = R.string.localizable.trade_pro_description()
        }
    }
    
}
