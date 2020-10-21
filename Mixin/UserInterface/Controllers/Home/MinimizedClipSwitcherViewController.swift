import UIKit
import MixinServices

class MinimizedClipSwitcherViewController: HomeOverlayViewController {
    
    @IBOutlet weak var leftIconBackgroundView: UIView!
    @IBOutlet weak var leftAvatarImageView: AvatarImageView!
    @IBOutlet weak var middleIconBackgroundView: UIView!
    @IBOutlet weak var middleAvatarImageView: AvatarImageView!
    @IBOutlet weak var rightIconBackgroundView: UIView!
    @IBOutlet weak var rightLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    @IBOutlet weak var leftIconTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var middleIconTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightIconTrailingConstraint: NSLayoutConstraint!
    
    var clips: [Clip] = [] {
        didSet {
            loadViewIfNeeded()
            updateViews()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let switcher = UIApplication.homeContainerViewController?.clipSwitcher {
            let action = #selector(ClipSwitcher.showFullscreenSwitcher)
            button.addTarget(switcher, action: action, for: .touchUpInside)
        }
    }
    
    private func loadClip(_ clip: Clip, to view: AvatarImageView) {
        view.prepareForReuse()
        view.imageView.tintColor = R.color.text_accessory()
        if let app = clip.app {
            view.imageView.contentMode = .scaleAspectFill
            view.setImage(app: app)
        } else {
            view.imageView.contentMode = .center
            view.image = R.image.ic_clip_webpage()
        }
    }
    
    private func updateViews() {
        switch clips.count {
        case 0:
            view.alpha = 0
        case 1:
            view.alpha = 1
            
            loadClip(clips[0], to: leftAvatarImageView)
            
            leftIconTrailingConstraint.priority = .defaultHigh
            middleIconTrailingConstraint.priority = .defaultLow
            rightIconTrailingConstraint.priority = .defaultLow
            middleIconBackgroundView.isHidden = true
            rightIconBackgroundView.isHidden = true
        case 2:
            view.alpha = 1
            
            loadClip(clips[0], to: leftAvatarImageView)
            loadClip(clips[1], to: middleAvatarImageView)
            
            leftIconTrailingConstraint.priority = .defaultLow
            middleIconTrailingConstraint.priority = .defaultHigh
            rightIconTrailingConstraint.priority = .defaultLow
            middleIconBackgroundView.isHidden = false
            rightIconBackgroundView.isHidden = true
        default:
            view.alpha = 1
            
            loadClip(clips[0], to: leftAvatarImageView)
            loadClip(clips[1], to: middleAvatarImageView)
            rightLabel.text = "+\(clips.count - 2)"
            
            leftIconTrailingConstraint.priority = .defaultLow
            middleIconTrailingConstraint.priority = .defaultLow
            rightIconTrailingConstraint.priority = .defaultHigh
            middleIconBackgroundView.isHidden = false
            rightIconBackgroundView.isHidden = false
        }
        
        self.view.layoutIfNeeded()
        self.updateViewSize()
        self.panningController.stickViewToParentEdge(horizontalVelocity: nil, animated: false)
    }
    
}
