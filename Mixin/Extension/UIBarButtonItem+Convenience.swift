import UIKit
import MixinServices

extension UIBarButtonItem {
    
    static func tintedIcon(image: UIImage?, target: Any?, action: Selector?) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            image: image,
            style: .plain,
            target: target,
            action: action
        )
        item.tintColor = R.color.icon_tint()
        return item
    }
    
    static func button(title: String?, target: Any?, action: Selector?) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            title: title,
            style: .plain,
            target: target,
            action: action
        )
        item.tintColor = R.color.theme()
        return item
    }
    
    static func busyIndicator() -> UIBarButtonItem {
        let indicator = ActivityIndicatorView()
        indicator.tintColor = R.color.text_tertiary()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 44),
            indicator.heightAnchor.constraint(equalToConstant: 44),
        ])
        indicator.startAnimating()
        return UIBarButtonItem(customView: indicator)
    }
    
    static func customerService(target: Any?, action: Selector) -> UIBarButtonItem {
        tintedIcon(image: R.image.customer_service(), target: target, action: action)
    }
    
    static func cancelSearch(target: Any?, action: Selector) -> UIBarButtonItem {
        var config: UIButton.Configuration = .plain()
        config.attributedTitle = AttributedString(
            string: R.string.localizable.cancel(),
            textStyle: .callout
        )
        config.baseForegroundColor = .theme
        
        if #unavailable(iOS 26.0) {
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0)
        }
        let button = UIButton(configuration: config)
        button.addTarget(target, action: action, for: .touchUpInside)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.sizeToFit()
        
        let item = UIBarButtonItem(customView: button)
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        return item
    }
    
}
