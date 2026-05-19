import UIKit

final class OpenPerpetualActionView: UIView {
    
    enum ButtonsAvailability {
        case allEnabled
        case allDisabled
        case multipleValues
    }
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    private(set) lazy var regularFontAttributes = {
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 16)
        )
        return attributes
    }()
    
    private(set) lazy var mediumFontAttributes = {
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 16, weight: .medium)
        )
        return attributes
    }()
    
    var buttonsAvailability: ButtonsAvailability {
        get {
            switch (leftButton.isEnabled, rightButton.isEnabled) {
            case (true, true):
                    .allEnabled
            case (false, false):
                    .allDisabled
            default:
                    .multipleValues
            }
        }
        set {
            switch newValue {
            case .allEnabled:
                leftButton.isEnabled = true
                rightButton.isEnabled = true
            case .allDisabled:
                leftButton.isEnabled = false
                rightButton.isEnabled = false
            case .multipleValues:
                assertionFailure("Set availability one-by-one")
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 82)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leftButton.titleLabel?.adjustsFontForContentSizeCategory = true
        rightButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    func loadLongShortConfiguration() {
        if var config = leftButton.configuration {
            config.baseBackgroundColor = MarketColor.rising.uiColor
            config.baseForegroundColor = .white
            config.attributedTitle = AttributedString(
                R.string.localizable.long(),
                attributes: regularFontAttributes
            )
            leftButton.configuration = config
        }
        if var config = rightButton.configuration {
            config.baseBackgroundColor = MarketColor.falling.uiColor
            config.baseForegroundColor = .white
            config.attributedTitle = AttributedString(
                R.string.localizable.short(),
                attributes: regularFontAttributes
            )
            rightButton.configuration = config
        }
    }
    
}
