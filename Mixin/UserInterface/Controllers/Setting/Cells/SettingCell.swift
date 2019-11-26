import UIKit

final class SettingCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var accessoryImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        subtitleLabel.isHidden = true
    }
    
}
