import UIKit

final class CompatibleBadgeBarButtonItem: UIBarButtonItem {
    
    var compatibleBadge: BadgeBarButtonView.Badge? {
        didSet {
            if #available(iOS 26.0, *) {
                switch compatibleBadge {
                case .unread:
                    var badge: Badge = .indicator()
                    badge.backgroundColor = R.color.error_red()
                    super.badge = badge
                case .count(let count):
                    var badge: Badge = .count(count)
                    badge.backgroundColor = R.color.theme()
                    badge.foregroundColor = .white
                    super.badge = badge
                case nil:
                    super.badge = nil
                }
            } else {
                (customView as? BadgeBarButtonView)?.badge = compatibleBadge
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    convenience init(image: UIImage, target: Any, action: Selector) {
        if #available(iOS 26.0, *) {
            self.init(image: image, style: .plain, target: target, action: action)
            tintColor = R.color.icon_tint()
        } else {
            let view = BadgeBarButtonView(image: image, target: target, action: action)
            self.init(customView: view)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
}
