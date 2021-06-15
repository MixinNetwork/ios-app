import UIKit

final class ScreenLockView: UIView, XibDesignable {
        
    @IBOutlet weak var unlockTipLabel: UILabel!
    @IBOutlet weak var unlockButton: UIButton!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            updateBackgroundViewEffect()
        }
    }
    
    func showUnlockOption(_ show: Bool) {
        contentView.isHidden = !show
    }
    
    private func updateUI() {
        updateBackgroundViewEffect()
        contentView.isHidden = true
        unlockTipLabel.text = R.string.localizable.screen_lock_unlock_tip(biometryType.localizedName)
        unlockButton.setTitle(R.string.localizable.screen_lock_unlock_button_title(biometryType.localizedName), for: .normal)
    }
    
    private func updateBackgroundViewEffect() {
        backgroundView.effect = UserInterfaceStyle.current == .light ? .lightBlur : .darkBlur
    }
    
    @IBAction func tapUnlockButtonAction(_ sender: Any) {
        tapUnlockAction?()
    }
    
}
