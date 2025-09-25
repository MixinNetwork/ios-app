import UIKit

final class MembershipInviteCell: UITableViewCell {
    
    @IBOutlet weak var gradientBackgroundView: GradientView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var disclosureIndicatorView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        gradientBackgroundView.lightColors = [
            UIColor(red: 0.901, green: 0.945, blue: 1, alpha: 1),
            UIColor(red: 0.948, green: 0.908, blue: 1, alpha: 1),
        ]
        gradientBackgroundView.darkColors = gradientBackgroundView.lightColors
        gradientBackgroundView.gradientLayer.startPoint = CGPoint(x: 0.25, y: 0.5)
        gradientBackgroundView.gradientLayer.endPoint = CGPoint(x: 0.75, y: 0.5)
        label.text = R.string.localizable.referral_banner()
        label.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .medium),
            adjustForContentSize: true
        )
        disclosureIndicatorView.image = R.image.ic_accessory_disclosure()?
            .withRenderingMode(.alwaysTemplate)
    }
    
}
