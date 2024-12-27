import UIKit

final class SwapTokenCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: BadgeIconView!
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
        iconView.badgeIconDiameter = 11
        chainLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        chainLabel.layer.cornerRadius = 4
        chainLabel.layer.masksToBounds = true
        subtitleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
}
