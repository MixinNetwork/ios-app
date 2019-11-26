import UIKit

final class GalleryVideoControlView: UIView, GalleryAnimatable {
    
    enum PlayControlStyle {
        case reload
        case play
        case pause
    }
    
    struct Style: OptionSet {
        let rawValue: Int
        static let pip = Style(rawValue: 1 << 0)
        static let liveStream = Style(rawValue: 1 << 1)
        static let loading = Style(rawValue: 1 << 2)
    }
    
    @IBOutlet weak var visualControlWrapperView: UIView!
    @IBOutlet weak var visualControlBackgroundImageView: UIImageView!
    @IBOutlet weak var pipButton: UIButton!
    @IBOutlet weak var liveBadgeView: UIImageView!
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var playControlWrapperView: UIView!
    @IBOutlet weak var reloadButton: RoundedBlurButton!
    @IBOutlet weak var playButton: RoundedBlurButton!
    @IBOutlet weak var pauseButton: RoundedBlurButton!
    
    @IBOutlet weak var timeControlWrapperView: UIView!
    @IBOutlet weak var playedTimeLabel: UILabel!
    @IBOutlet weak var slider: GalleryVideoSlider!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    
    @IBOutlet weak var activityIndicatorView: GalleryActivityIndicatorView!
    
    @IBOutlet weak var visualControlTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var visualControlLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var visualControlTrailingConstraint: NSLayoutConstraint!
    
    var playControlStyle: PlayControlStyle = .play {
        didSet {
            updatePlayControlButtons()
        }
    }
    
    var style: Style = [] {
        didSet {
            updateControls()
        }
    }
    
    private let pipModePlayControlTransform = CGAffineTransform(scaleX: 0.64, y: 0.64)
    
    private var playControlsHidden = true
    private var otherControlsHidden = true
    
    override func awakeFromNib() {
        super.awakeFromNib()
        for button in [reloadButton, playButton, pauseButton] {
            button!.backgroundSize = CGSize(width: 60, height: 60)
        }
    }
    
    func set(playControlsHidden: Bool, otherControlsHidden: Bool, animated: Bool) {
        self.playControlsHidden = playControlsHidden
        self.otherControlsHidden = otherControlsHidden
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(animationDuration)
        }
        updateControls()
        if animated {
            UIView.commitAnimations()
        }
    }
    
    @objc private func hideControls() {
        set(playControlsHidden: true, otherControlsHidden: true, animated: true)
    }
    
    private func updatePlayControlButtons() {
        reloadButton.isHidden = playControlStyle != .reload
        playButton.isHidden = playControlStyle != .play
        pauseButton.isHidden = playControlStyle != .pause
    }
    
    private func updateControls() {
        updatePlayControlButtons()
        
        visualControlWrapperView.alpha = otherControlsHidden ? 0 : 1
        let showLiveBadge = style.contains(.liveStream) && !style.contains(.pip)
        liveBadgeView.alpha = showLiveBadge ? 1 : 0
        
        let transform = style.contains(.pip) ? pipModePlayControlTransform : .identity
        playControlWrapperView.transform = transform
        playControlWrapperView.alpha = playControlsHidden || style.contains(.loading) ? 0 : 1
        
        activityIndicatorView.transform = transform
        activityIndicatorView.isAnimating = style.contains(.loading)
        
        let hideTimeControl = otherControlsHidden
            || style.contains(.pip)
            || style.contains(.liveStream)
        timeControlWrapperView.alpha = hideTimeControl ? 0 : 1
        
        visualControlBackgroundImageView.alpha = style.contains(.pip) ? 0 : 1
        
        let constraints = [
            visualControlLeadingConstraint,
            visualControlTrailingConstraint,
            visualControlTopConstraint
        ]
        for constraint in constraints {
            constraint?.constant = style.contains(.pip) ? 0 : 12
        }
    }
    
}
