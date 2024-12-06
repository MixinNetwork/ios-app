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
    
    static func busyButton(title: String?, target: Any?, action: Selector) -> UIBarButtonItem {
        let button = BusyButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(R.color.theme(), for: .normal)
        button.setTitleColor(R.color.button_background_disabled(), for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.addTarget(target, action: action, for: .touchUpInside)
        let item = UIBarButtonItem(customView: button)
        return item
    }
    
    static func customerService(target: Any?, action: Selector?) -> UIBarButtonItem {
        tintedIcon(image: R.image.customer_service(), target: target, action: action)
    }
    
}
