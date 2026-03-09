import UIKit

final class OpenPerpetualActionView: UIView {
    
    @IBOutlet weak var longButton: UIButton!
    @IBOutlet weak var shortButton: UIButton!
    
    var isEnabled: Bool = true {
        didSet {
            longButton.isEnabled = isEnabled
            shortButton.isEnabled = isEnabled
        }
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 82)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        var actionAttributes = AttributeContainer()
        actionAttributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 16, weight: .medium)
        )
        if var config = longButton.configuration {
            config.baseBackgroundColor = MarketColor.rising.uiColor
            config.attributedTitle = AttributedString(
                R.string.localizable.long(),
                attributes: actionAttributes
            )
            longButton.configuration = config
        }
        if var config = shortButton.configuration {
            config.baseBackgroundColor = MarketColor.falling.uiColor
            config.attributedTitle = AttributedString(
                R.string.localizable.short(),
                attributes: actionAttributes
            )
            shortButton.configuration = config
        }
    }
    
}
