import UIKit

final class OnboardingBannerCell: UICollectionViewCell {
    
    @IBOutlet weak var imageBackgroundView: GradientView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // It's OK even the height is 0. Those images have enough top spacing.
        imageViewTopConstraint.constant = UIApplication.shared.statusBarFrame.height
        imageBackgroundView.lightColors = [
            UIColor(displayP3RgbValue: 0xFFFFFF),
            UIColor(displayP3RgbValue: 0xF7F7F7),
        ]
        imageBackgroundView.darkColors = [
            UIColor(displayP3RgbValue: 0x2C3136),
            UIColor(displayP3RgbValue: 0x1C2029),
        ]
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 24, weight: .semibold),
            adjustForContentSize: true
        )
    }
    
}
