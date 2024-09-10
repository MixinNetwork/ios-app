import UIKit
import MixinServices

final class MarketColorTintedImageView: UIImageView {
    
    var marketColor: MarketColor? {
        didSet {
            reloadTintColor()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTintColor),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTintColor),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func reloadTintColor() {
        guard let color = marketColor else {
            return
        }
        self.tintColor = color.uiColor
    }
    
}
