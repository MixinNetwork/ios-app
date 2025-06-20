import UIKit

final class AuthenticationPreviewDialogView: UIView {
    
    enum Style {
        case gray
        case red
        case yellow
    }
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    var style: Style = .red {
        didSet {
            updateTintColors(trait: traitCollection)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.borderWidth = 1
        contentView.layer.cornerRadius = 8
        stepLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        leftButton.titleLabel?.adjustsFontSizeToFitWidth = true
        rightButton.titleLabel?.adjustsFontSizeToFitWidth = true
        updateTintColors(trait: traitCollection)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateTintColors(trait: traitCollection)
        }
    }
    
    private func updateTintColors(trait: UITraitCollection) {
        let backgroundColor = switch style {
        case .gray:
            R.color.text_tertiary()!
        case .red:
            R.color.red()!
        case .yellow:
            UIColor(displayP3RgbValue: 0xfacd59)
        }
        contentView.layer.borderColor = backgroundColor.resolvedColor(with: trait).cgColor
        contentView.backgroundColor = backgroundColor.withAlphaComponent(0.1)
        
        let textColor = switch style {
        case .gray, .yellow:
            R.color.text()!
        case .red:
            R.color.red()!
        }
        stepLabel.textColor = textColor
        titleLabel.textColor = textColor
        
        iconImageView.tintColor = switch style {
        case .gray:
            R.color.text_secondary()!
        case .red:
            R.color.red()!
        case .yellow:
            UIColor(displayP3RgbValue: 0xf6a417)
        }
    }
    
}
