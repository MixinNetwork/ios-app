import UIKit
import MixinServices

class CurrencyCell: UITableViewCell {
    
    @IBOutlet weak var checkmarkImageView: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var codeLabel: UILabel!
    
    private var iconLayer: CALayer {
        iconImageView.layer
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        iconLayer.shadowOpacity = 1
        iconLayer.shadowRadius = 8
        iconLayer.shadowOffset = CGSize(width: 0, height: 2)
        updateShadowColor()
    }
    
    override func layoutSubviews() {
        let iconFrameBefore = iconImageView.frame
        super.layoutSubviews()
        if iconImageView.frame != iconFrameBefore, let icon = iconImageView.image {
            updateShadowPath(iconSize: icon.size)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateShadowColor()
    }
    
    func render(currency: Currency) {
        let icon = currency.icon
        iconImageView.image = icon
        updateShadowPath(iconSize: icon.size)
        codeLabel.text = currency.code + " (" + currency.symbol + ")"
    }
    
    private func updateShadowColor() {
        switch UserInterfaceStyle.current {
        case .light:
            iconLayer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        case .dark:
            iconLayer.shadowColor = UIColor.black.withAlphaComponent(0.20).cgColor
        }
    }
    
    private func updateShadowPath(iconSize: CGSize) {
        let shadowOrigin = CGPoint(x: (iconImageView.bounds.width - iconSize.width) / 2,
                                   y: (iconImageView.bounds.height - iconSize.height) / 2)
        iconLayer.shadowPath = CGPath(roundedRect: CGRect(origin: shadowOrigin, size: iconSize),
                                      cornerWidth: iconSize.width / 2,
                                      cornerHeight: iconSize.height / 2,
                                      transform: nil)
        
    }
    
}
