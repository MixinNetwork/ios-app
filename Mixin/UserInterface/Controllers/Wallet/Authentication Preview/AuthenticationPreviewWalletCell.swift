import UIKit
import MixinServices

final class AuthenticationPreviewWalletCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var subtitleStackView: UIStackView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    private weak var tagLabel: InsetLabel?
    
    var walletTag: String? {
        didSet {
            if let walletTag {
                let label: InsetLabel
                if let tagLabel {
                    label = tagLabel
                } else {
                    label = InsetLabel()
                    label.layer.cornerRadius = 4
                    label.layer.masksToBounds = true
                    label.font = .preferredFont(forTextStyle: .caption1)
                    label.adjustsFontForContentSizeCategory = true
                    label.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
                    label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                    label.backgroundColor = R.color.background_quaternary()
                    label.textColor = R.color.text_quaternary()
                    subtitleStackView.addArrangedSubview(label)
                    self.tagLabel = label
                }
                label.text = walletTag
            } else {
                tagLabel?.removeFromSuperview()
                tagLabel = nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        captionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
}
