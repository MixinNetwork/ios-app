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
    
    static func customerService(target: Any?, action: Selector?) -> UIBarButtonItem {
        tintedIcon(image: R.image.customer_service(), target: target, action: action)
    }
    
}
