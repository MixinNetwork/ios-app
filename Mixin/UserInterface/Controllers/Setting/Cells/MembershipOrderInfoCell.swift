import UIKit
import SDWebImage

final class MembershipOrderInfoCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
}
