import UIKit

final class GalleryVideoControlView: UIView, GalleryAnimatable {
    
    enum PlayControlStyle {
        case reload
        case play
        case pause
    }
    
    @IBOutlet weak var visualControlWrapperView: UIView!
    @IBOutlet weak var pipButton: UIButton!
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
    
    var isPipMode = false {
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
        playButton.isHidden = playControlStyle != .play || isPipMode
        pauseButton.isHidden = playControlStyle != .pause || isPipMode
    }
    
    private func updateControls() {
        updatePlayControlButtons()
        playControlWrapperView.alpha = playControlsHidden ? 0 : 1
        visualControlWrapperView.alpha = otherControlsHidden ? 0 : 1
        timeControlWrapperView.alpha = otherControlsHidden || isPipMode ? 0 : 1
    }
    
}
