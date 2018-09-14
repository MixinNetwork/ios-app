import UIKit

class AuthorizationTableViewCell: UITableViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = label.frame.origin.x
    }
}
