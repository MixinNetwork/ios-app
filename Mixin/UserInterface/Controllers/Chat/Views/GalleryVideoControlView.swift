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
    }
    
    @IBOutlet weak var visualControlWrapperView: UIView!
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
    
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    
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
    
    private var playControlsHidden = true
    private var otherControlsHidden = true
    
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
    
    private func updatePlayControlButtons() {
        reloadButton.isHidden = playControlStyle != .reload
        playButton.isHidden = playControlStyle != .play || style.contains(.pip)
        pauseButton.isHidden = playControlStyle != .pause || style.contains(.pip)
    }
    
    private func updateControls() {
        updatePlayControlButtons()
        let showLiveBadge = style.contains(.liveStream) && !style.contains(.pip)
        liveBadgeView.alpha = showLiveBadge ? 1 : 0
        playControlWrapperView.alpha = playControlsHidden ? 0 : 1
        visualControlWrapperView.alpha = otherControlsHidden ? 0 : 1
        let hideTimeControl = otherControlsHidden
            || style.contains(.pip)
            || style.contains(.liveStream)
        timeControlWrapperView.alpha = hideTimeControl ? 0 : 1
    }
    
}
