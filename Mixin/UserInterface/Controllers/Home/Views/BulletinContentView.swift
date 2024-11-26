import UIKit

class BulletinContentView: UIView {
    
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var continueButton: RoundedButton!
    
    var content: BulletinContent? = nil {
        didSet {
            switch content {
            case .backupMnemonics:
                titleLabel.text = R.string.localizable.backup_mnemonic_phrase()
                descriptionLabel.text = R.string.localizable.backup_mnemonic_phrase_desc()
                continueButton.setTitle(R.string.localizable.backup_now(), for: .normal)
                closeButton.isHidden = true
            case .notification:
                titleLabel.text = R.string.localizable.turn_on_notifications()
                descriptionLabel.text = R.string.localizable.notification_content()
                continueButton.setTitle(R.string.localizable.settings(), for: .normal)
                closeButton.isHidden = false
            case .emergencyContact:
                titleLabel.text = R.string.localizable.emergency_contact()
                descriptionLabel.text = R.string.localizable.setting_emergency_content()
                continueButton.setTitle(R.string.localizable.settings(), for: .normal)
                closeButton.isHidden = false
            case .appUpdate:
                titleLabel.text = R.string.localizable.new_update_available()
                descriptionLabel.text = R.string.localizable.new_update_available_desc()
                continueButton.setTitle(R.string.localizable.update_now(), for: .normal)
                closeButton.isHidden = false
            case .none:
                titleLabel.text = nil
                descriptionLabel.text = nil
                continueButton.setTitle(nil, for: .normal)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let closeImage = R.image.ic_announcement_close()!.withRenderingMode(.alwaysTemplate)
        closeButton.setImage(closeImage, for: .normal)
    }
    
}
