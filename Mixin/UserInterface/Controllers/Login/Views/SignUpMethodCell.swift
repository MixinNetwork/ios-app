import UIKit

final class SignUpMethodCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let selectedBackgroundView = UIView(frame: bounds)
        selectedBackgroundView.backgroundColor = R.color.background_secondary()
        self.selectedBackgroundView = selectedBackgroundView
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
    }
    
}
