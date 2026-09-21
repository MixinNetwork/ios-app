import UIKit

final class PerpPositionAdjustmentIntroductionCell: UICollectionViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let texts = [
            R.string.localizable.perps_margin_or_position(),
            "• " + R.string.localizable.perps_margin_tip(),
            "• " + R.string.localizable.perps_position_tip(),
            "• " + R.string.localizable.perps_low_margin_tip(),
        ]
        for text in texts {
            let label = UILabel()
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
            label.textColor = R.color.text_tertiary()
            label.numberOfLines = 0
            label.text = text
            contentStackView.addArrangedSubview(label)
        }
    }
    
}
