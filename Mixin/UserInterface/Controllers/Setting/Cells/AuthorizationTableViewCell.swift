import UIKit

class AuthorizationTableViewCell: UITableViewCell {
    
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
}
