import UIKit
import MixinServices

extension UIBarButtonItem {
    
    static func navigationBack(target: Any?, action: Selector?) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            image: R.image.navigation_back(),
            style: .plain,
            target: target,
            action: action
        )
        item.tintColor = R.color.icon_tint()
        return item
    }
    
}
