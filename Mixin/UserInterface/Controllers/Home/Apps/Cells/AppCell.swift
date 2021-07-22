import UIKit

class AppCell: ShakableCell {
    
    @IBOutlet weak var imageView: AvatarImageView?
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var imageContainerView: UIView!
    
    var item: AppItem? {
        didSet {
            updateUI()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.prepareForReuse()
        label?.isHidden = false
    }
    
    func updateUI() {
        guard let item = item as? AppModel else {
            return
        }
        switch item.app {
        case .embedded(let embedded):
            imageView?.contentMode = .center
            label?.text = embedded.name
            imageView?.image = embedded.icon
        case .external(let user):
            imageView?.contentMode = .scaleAspectFit
            label?.text = user.fullName
            imageView?.setImage(with: user)
        }
        label?.alpha = 1
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
    
    var generalItem: AppItem? {
        get {
            item
        }
        set {
            item = newValue
        }
    }
    
}
