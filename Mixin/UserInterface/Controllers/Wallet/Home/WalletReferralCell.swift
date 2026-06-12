import UIKit
import MixinServices

final class WalletReferralCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func walletReferralCellDidSelectClose(_ cell: WalletReferralCell)
        func walletReferralCellDidSelectLearnMore(_ cell: WalletReferralCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var learnMoreButton: UIButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.wallet_home_referral_banner_title()
        descriptionLabel.attributedText = {
            let rate = PercentageFormatter.string(
                from: 0.6,
                format: .precision,
                sign: .never
            )
            let description = R.string.localizable.wallet_home_referral_banner_desc(rate)
            let text = NSMutableAttributedString(
                string: description,
                attributes: [
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.text_tertiary()!,
                ]
            )
            let rateRange = (description as NSString).range(
                of: rate,
                options: .backwards
            )
            let rateAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: R.color.referral_rebating()!,
                .font: UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 14, weight: .medium)
                ),
            ]
            text.setAttributes(rateAttributes, range: rateRange)
            return text
        }()
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        learnMoreButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.learn_more(),
            attributes: attributes
        )
        learnMoreButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func close(_ sender: Any) {
        delegate?.walletReferralCellDidSelectClose(self)
    }
    
    @IBAction func learnMore(_ sender: Any) {
        delegate?.walletReferralCellDidSelectLearnMore(self)
    }
    
}
