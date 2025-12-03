import UIKit

final class TradeTokenCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var maliciousWarningImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var chainLabel: InsetLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var checkmarkImageView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            checkmarkImageView.isHidden = !isSelected
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleStackView.setCustomSpacing(6, after: maliciousWarningImageView)
        chainLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        chainLabel.layer.cornerRadius = 4
        chainLabel.layer.masksToBounds = true
        subtitleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
}
