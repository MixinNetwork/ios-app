import UIKit

final class ExploreActionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconTrayImageView: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var badgeView: BadgeDotView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        badgeView.dotSize = CGSize(width: 10, height: 10)
    }
    
    func load(action: ExploreAction) {
        iconTrayImageView.image = action.trayImage
        iconImageView.image = action.iconImage
        titleLabel.text = action.title
        subtitleLabel.text = action.subtitle
    }
    
}
