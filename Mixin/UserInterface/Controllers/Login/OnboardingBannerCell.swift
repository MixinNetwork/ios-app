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
        resizeImageView(size: traitCollection.preferredContentSizeCategory)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            resizeImageView(size: traitCollection.preferredContentSizeCategory)
        }
    }
    
    private func resizeImageView(size: UIContentSizeCategory) {
        switch ScreenHeight.current {
        case .short:
            fallthrough
        case .medium where size > .large:
            imageView.snp.remakeConstraints { make in
                make.width.equalTo(imageView.snp.height).multipliedBy(375.0 / 310.0 * 1.5)
            }
        case .medium:
            imageView.snp.remakeConstraints { make in
                make.width.equalTo(imageView.snp.height).multipliedBy(375.0 / 310.0)
            }
        case .long, .extraLong:
            imageView.snp.remakeConstraints { make in
                make.width.equalTo(imageView.snp.height).multipliedBy(375.0 / 310.0)
            }
        }
    }
    
}
