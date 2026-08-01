import UIKit

final class MarketDisplaySettingCell: UITableViewCell {
    
    @IBOutlet weak var contentBackgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentBackgroundView.layer.cornerRadius = 13
        contentBackgroundView.layer.masksToBounds = true
        subtitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        actionButton.showsMenuAsPrimaryAction = true
    }
    
}
