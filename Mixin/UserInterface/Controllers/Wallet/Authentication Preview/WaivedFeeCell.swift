import UIKit

final class WaivedFeeCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var primaryLabel: UILabel!
    @IBOutlet weak var freeLabel: InsetLabel!
    @IBOutlet weak var secondaryLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(8, after: captionLabel)
        captionLabel.text = R.string.localizable.fee().uppercased()
        freeLabel.contentInset = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        freeLabel.layer.cornerRadius = 4
        freeLabel.layer.masksToBounds = true
        freeLabel.text = R.string.localizable.free()
        secondaryLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func updatePrimaryLabel(text: String) {
        primaryLabel.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .callout),
                .foregroundColor: R.color.text()!,
                .strikethroughColor: R.color.text()!,
                .strikethroughStyle: NSNumber(value: NSUnderlineStyle.single.rawValue),
            ]
        )
    }
    
}
