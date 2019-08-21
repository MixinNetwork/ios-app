import UIKit

class AuthorizationTableViewCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
}
