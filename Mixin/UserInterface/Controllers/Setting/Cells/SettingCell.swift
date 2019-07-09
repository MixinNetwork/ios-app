import UIKit

final class SettingCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var accessoryImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
        subtitleLabel.isHidden = true
    }
    
}
