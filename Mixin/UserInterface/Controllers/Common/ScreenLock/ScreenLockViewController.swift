import UIKit

class ScreenLockViewController: UIViewController {
    
    @IBOutlet weak var unlockTipLabel: UILabel!
    @IBOutlet weak var unlockButton: UIButton!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    
    var tapUnlockAction: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundView.effect = .regularBlur
        contentView.isHidden = true
        unlockTipLabel.text = R.string.localizable.screen_lock_unlock_tip(biometryType.localizedName)
        unlockButton.setTitle(R.string.localizable.screen_lock_unlock_button_title(biometryType.localizedName), for: .normal)
    }
    
    func showUnlockOption(_ show: Bool) {
        contentView.isHidden = !show
    }
    
    @IBAction func tapUnlockButtonAction(_ sender: Any) {
        tapUnlockAction?()
    }
    
}
