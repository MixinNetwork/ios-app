import UIKit

final class BadgeBarButtonItem: UIBarButtonItem {
    
    let view: BadgeBarButtonView
    
    var compatibleBadge: BadgeBarButtonView.Badge? {
        didSet {
            view.badge = compatibleBadge
        }
    }
    
    init(image: UIImage, target: Any, action: Selector) {
        view = BadgeBarButtonView(image: image, target: target, action: action)
        super.init()
        self.customView = view
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
}
