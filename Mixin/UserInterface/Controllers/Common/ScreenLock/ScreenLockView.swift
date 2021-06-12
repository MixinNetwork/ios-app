import UIKit

final class ScreenLockView: UIView, XibDesignable {
        
    @IBOutlet weak var unlockTipLabel: UILabel!
    @IBOutlet weak var unlockButton: UIButton!
    @IBOutlet weak var wrapperView: UIView!
    
    var tapUnlockAction: (() -> Void)?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
        updateUI()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        updateUI()
    }
    
    func showUnlockOption(_ show: Bool) {
        wrapperView.isHidden = !show
    }
    
    private func updateUI() {
        wrapperView.isHidden = true
        unlockTipLabel.text = R.string.localizable.screen_lock_unlock_tip(biometryType.localizedName)
        unlockButton.setTitle(R.string.localizable.screen_lock_unlock_button_title(biometryType.localizedName), for: .normal)
    }
    
    @IBAction func tapUnlockButtonAction(_ sender: Any) {
        tapUnlockAction?()
    }
    
}
