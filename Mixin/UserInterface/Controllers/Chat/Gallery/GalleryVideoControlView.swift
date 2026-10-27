import UIKit

final class GalleryVideoControlView: UIView, GalleryAnimatable {
    
    enum PlayControlStyle {
        case reload
        case play
        case pause
    }
    
    struct Style: OptionSet {
        let rawValue: Int
        static let liveStream = Style(rawValue: 1 << 1)
        static let loading = Style(rawValue: 1 << 2)
    }
    
    @IBOutlet weak var visualControlWrapperView: UIView!
    @IBOutlet weak var pipButton: RoundedBlurButton!
    @IBOutlet weak var liveBadgeView: UIImageView!
    @IBOutlet weak var closeButton: RoundedBlurButton!
    
    @IBOutlet weak var playControlWrapperView: UIView!
    @IBOutlet weak var reloadButton: RoundedBlurButton!
    @IBOutlet weak var playButton: RoundedBlurButton!
    @IBOutlet weak var pauseButton: RoundedBlurButton!
    
    @IBOutlet weak var timeControlWrapperView: UIView!
    @IBOutlet weak var playedTimeLabel: UILabel!
    @IBOutlet weak var slider: GalleryVideoSlider!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    
    @IBOutlet weak var activityIndicatorView: GalleryActivityIndicatorView!
    
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        for button in [reloadButton, playButton, pauseButton] {
            button!.backgroundSize = CGSize(width: 56, height: 56)
        }
        for button in [pipButton, closeButton] {
            button!.backgroundSize = CGSize(width: 46, height: 36)
            button!.cornerRadius = 12
        }
    }
    
    func set(playControlsHidden: Bool, otherControlsHidden: Bool, animated: Bool) {
        self.playControlsHidden = playControlsHidden
        self.otherControlsHidden = otherControlsHidden
        if animated {
            UIView.animate(withDuration: animationDuration, animations: updateControls)
        } else {
            updateControls()
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
        liveBadgeView.alpha = style.contains(.liveStream) ? 1 : 0
        playControlWrapperView.alpha = playControlsHidden || style.contains(.loading) ? 0 : 1
        activityIndicatorView.isAnimating = style.contains(.loading)
        
        let hideTimeControl = otherControlsHidden || style.contains(.liveStream)
        timeControlWrapperView.alpha = hideTimeControl ? 0 : 1
    }
    
}
