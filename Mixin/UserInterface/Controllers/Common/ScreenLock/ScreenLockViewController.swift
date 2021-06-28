import UIKit

class ScreenLockViewController: UIViewController {
    
    @IBOutlet weak var unlockTipLabel: UILabel!
    @IBOutlet weak var unlockButton: UIButton!
    @IBOutlet weak var unlockContentView: UIView!
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    @IBOutlet weak var logoContentView: UIView!
    @IBOutlet weak var logoImageViewTopSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var logoImageViewHeightConstraint: NSLayoutConstraint!
    
    var tapUnlockAction: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundView.effect = .regularBlur
        unlockContentView.isHidden = true
        logoContentView.isHidden = false
        logoImageViewTopSpaceConstraint.constant = (UIScreen.main.bounds.height - logoImageViewHeightConstraint.constant) / 10 * 4
        unlockTipLabel.text = R.string.localizable.screen_lock_unlock_tip(biometryType.localizedName)
        unlockButton.setTitle(R.string.localizable.screen_lock_unlock_button_title(biometryType.localizedName), for: .normal)
    }
    
    func showUnlockOption(_ show: Bool) {
        unlockContentView.isHidden = !show
        logoContentView.isHidden = show
    }
    
    @IBAction func tapUnlockButtonAction(_ sender: Any) {
        tapUnlockAction?()
    }
    
}
