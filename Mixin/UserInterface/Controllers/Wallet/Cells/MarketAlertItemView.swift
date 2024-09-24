import UIKit

final class MarketAlertItemView: UIView {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        actionButton.showsMenuAsPrimaryAction = true
    }
    
}
