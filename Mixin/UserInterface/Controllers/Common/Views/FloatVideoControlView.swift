import UIKit

final class FloatVideoControlView: UIView {
    
    @IBOutlet weak var pipButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var reloadButton: RoundedBlurButton!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    
    func set(reloadButtonHidden: Bool, activityIndicatorHidden: Bool) {
        reloadButton.isHidden = reloadButtonHidden
        activityIndicatorHidden
            ? activityIndicatorView.stopAnimating()
            : activityIndicatorView.startAnimating()
    }
    
}
