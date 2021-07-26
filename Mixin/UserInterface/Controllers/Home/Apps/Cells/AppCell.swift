import UIKit

class AppCell: ShakableCell {
    
    @IBOutlet weak var imageView: AvatarImageView?
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var imageContainerView: UIView!
    
    var app: HomeApp? {
        didSet {
            switch app {
            case .embedded(let embedded):
                imageView?.contentMode = .center
                label?.text = embedded.name
                imageView?.image = embedded.icon
            case .external(let user):
                imageView?.contentMode = .scaleAspectFit
                label?.text = user.fullName
                imageView?.setImage(with: user)
            case .none:
                return
            }
            label?.alpha = 1
            label?.isHidden = false
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.prepareForReuse()
        label?.isHidden = false
    }
    
}

extension AppCell: HomeAppCell {
    
    var snapshotView: HomeAppsSnapshotView? {
        guard let iconView = imageContainerView.snapshotView(afterScreenUpdates: true) else {
            return nil
        }
        iconView.frame = imageContainerView.frame
        return HomeAppsSnapshotView(frame: bounds, iconView: iconView)
    }
    
    var item: HomeAppItem? {
        get {
            if let app = app {
                return .app(app)
            } else {
                return nil
            }
        }
        set {
            switch newValue {
            case let .app(app):
                self.app = app
            default:
                break
            }
        }
    }
    
}
