import UIKit

class MinimizedClipIconView: UIView {
    
    @IBOutlet weak var placeholderView: UIView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    
    var showsPlaceholder = false {
        didSet {
            placeholderView.alpha = showsPlaceholder ? 1 : 0
            avatarImageView.alpha = showsPlaceholder ? 0 : 1
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        placeholderView.layer.cornerRadius = min(placeholderView.bounds.width, placeholderView.bounds.height) / 2
    }
    
    func load(clip: Clip) {
        avatarImageView.prepareForReuse()
        if let app = clip.app {
            avatarImageView.imageView.contentMode = .scaleAspectFill
            avatarImageView.setImage(app: app)
        } else {
            avatarImageView.imageView.contentMode = .center
            avatarImageView.image = R.image.ic_clip_webpage()
            avatarImageView.imageView.backgroundColorIgnoringSystemSettings = R.color.background_secondary()!
        }
    }
    
}
