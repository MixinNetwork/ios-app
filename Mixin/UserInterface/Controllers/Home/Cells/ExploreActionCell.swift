import UIKit
import SDWebImage

final class ExploreActionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconTrayImageView: UIImageView!
    @IBOutlet weak var iconImageView: SDAnimatedImageView!
    @IBOutlet weak var badgeView: BadgeDotView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        iconImageView.shouldCustomLoopCount = true
        iconImageView.animationRepeatCount = 3
        badgeView.dotSize = CGSize(width: 10, height: 10)
    }
    
    func load(action: ExploreAction) {
        iconTrayImageView.image = action.trayImage
        iconImageView.image = action.iconImage
        titleLabel.text = action.title
        subtitleLabel.text = action.subtitle
    }
    
}
