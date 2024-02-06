import UIKit

final class PaymentPreviewDialogView: UIView {
    
    enum Style {
        case info
        case warning
    }
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    var style: Style = .warning {
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
        case .info:
            R.color.text_tertiary()!
        case .warning:
            R.color.red()!
        }
        contentView.layer.borderColor = backgroundColor.resolvedColor(with: trait).cgColor
        contentView.backgroundColor = backgroundColor.withAlphaComponent(0.1)
        
        let textColor = switch style {
        case .info:
            R.color.text()!
        case .warning:
            R.color.red()!
        }
        stepLabel.textColor = textColor
        titleLabel.textColor = textColor
        
        iconImageView.tintColor = switch style {
        case .info:
            R.color.text_secondary()!
        case .warning:
            R.color.red()!
        }
    }
    
}
