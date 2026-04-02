import UIKit

final class AddWalletFooterCell: UICollectionViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let texts = [
            R.string.localizable.is_it_safe_to_import_into_mixin(),
            "• " + R.string.localizable.mixin_import_safety_1(),
            "• " + R.string.localizable.mixin_import_safety_2(),
            "• " + R.string.localizable.mixin_import_safety_3(),
        ]
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.5
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.text_tertiary()!,
            .font: UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14)
            ),
            .paragraphStyle: paragraphStyle,
        ]
        for text in texts {
            let label = UILabel()
            label.attributedText = NSAttributedString(
                string: text,
                attributes: attributes
            )
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            contentStackView.addArrangedSubview(label)
        }
    }
    
}
