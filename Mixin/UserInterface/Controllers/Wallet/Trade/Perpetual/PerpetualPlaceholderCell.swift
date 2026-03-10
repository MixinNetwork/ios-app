import UIKit

final class PerpetualPlaceholderCell: UICollectionViewCell {
    
    @IBOutlet weak var emptyIndicatorStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var helpButton: UIButton!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    
    var onHelp: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        emptyIndicatorStackView.setCustomSpacing(12, after: iconImageView)
        titleLabel.text = R.string.localizable.no_position().uppercased()
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        helpButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.how_perps_works(),
            attributes: attributes
        )
        helpButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func askForHelp(_ sender: Any) {
        onHelp?()
    }
    
}
