import UIKit
import MixinServices

final class MarketColoredLabel: InsetLabel {
    
    override var textColor: UIColor! {
        willSet {
            marketColor = nil
        }
    }
    
    var marketColor: MarketColor? {
        didSet {
            reloadTextColor()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTextColor),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTextColor),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func reloadTextColor() {
        guard let color = marketColor else {
            return
        }
        self.textColor = color.uiColor
    }
    
}
