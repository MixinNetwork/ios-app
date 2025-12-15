import UIKit
import MixinServices

final class AuthenticationPreviewWalletCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var subtitleStackView: UIStackView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    private weak var tagLabel: UILabel?
    
    var walletTag: String? {
        didSet {
            if let walletTag {
                let label = tagLabel ?? {
                    let label = InsetLabel()
                    label.layer.cornerRadius = 4
                    label.layer.masksToBounds = true
                    label.font = .preferredFont(forTextStyle: .caption1)
                    label.adjustsFontForContentSizeCategory = true
                    label.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
                    label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                    label.backgroundColor = R.color.background_quaternary()
                    label.textColor = R.color.text_quaternary()
                    return label
                }()
                label.text = walletTag
                if label.superview == nil {
                    subtitleStackView.addArrangedSubview(label)
                }
            } else {
                tagLabel?.removeFromSuperview()
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
