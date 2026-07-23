import UIKit

final class MarketActionView: UIView {
    
    @IBOutlet weak var alertButton: UIButton!
    @IBOutlet weak var tradeButton: UIButton!
    
    var hasAlert = false {
        didSet {
            alertButton.configuration?.image = hasAlert
            ? R.image.alert_added()
            : R.image.alert_none()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        var alertAttributes = AttributeContainer()
        alertAttributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 10, weight: .medium)
        )
        alertButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.alert(),
            attributes: alertAttributes
        )
        alertButton.titleLabel?.adjustsFontForContentSizeCategory = true
        tradeButton.configuration?.title = R.string.localizable.trade()
        tradeButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
}
