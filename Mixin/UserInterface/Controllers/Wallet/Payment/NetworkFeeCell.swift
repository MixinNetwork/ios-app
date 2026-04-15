import UIKit

final class NetworkFeeCell: UITableViewCell {
    
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var checkmarkImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .clear
        self.selectedBackgroundView = selectedBackgroundView
    }
    
}
