import UIKit

final class WatchWalletAddressesIntroductionCell: UICollectionViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionTextView: IntroTextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contentStackView.setCustomSpacing(10, after: titleLabel)
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.watch_wallet()
        descriptionTextView.textContainerInset = .zero
        descriptionTextView.textContainer.lineFragmentPadding = 0
        descriptionTextView.adjustsFontForContentSizeCategory = true
        descriptionTextView.attributedText = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineHeightMultiple = 1.2
            let string = NSMutableAttributedString(
                string: R.string.localizable.watch_wallet_description(),
                attributes: [
                    .paragraphStyle: paragraphStyle,
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.text_secondary()!,
                ]
            )
            let learnMore = NSAttributedString(
                string: R.string.localizable.learn_more(),
                attributes: [
                    .paragraphStyle: paragraphStyle,
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.theme()!,
                    .link: URL.watchWallet,
                ]
            )
            string.append(learnMore)
            return string
        }()
    }
    
}
