import UIKit

final class FloatVideoControlView: UIView {
    
    @IBOutlet weak var pipButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var pauseButton: RoundedBlurButton!
    @IBOutlet weak var playButton: RoundedBlurButton!
    @IBOutlet weak var playedTimeLabel: UILabel!
    @IBOutlet weak var slider: GalleryVideoSlider!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    
}
