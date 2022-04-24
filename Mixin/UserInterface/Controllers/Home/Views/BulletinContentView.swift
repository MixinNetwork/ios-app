import UIKit

class BulletinContentView: UIView {
    
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var continueButton: RoundedButton!
    
    var content: BulletinContent? = nil {
        didSet {
            switch content {
            case .notification:
                titleLabel.text = R.string.localizable.turn_On_Notifications()
                descriptionLabel.text = R.string.localizable.notification_content()
                continueButton.setTitle(R.string.localizable.settings(), for: .normal)
            case .emergencyContact:
                titleLabel.text = R.string.localizable.emergency_Contact()
                descriptionLabel.text = R.string.localizable.setting_emergency_content()
                continueButton.setTitle(R.string.localizable.settings(), for: .normal)
            case .initializePIN:
                titleLabel.text = R.string.localizable.get_a_new_wallet()
                descriptionLabel.text = R.string.localizable.new_wallet_hint()
                continueButton.setTitle(R.string.localizable.continue(), for: .normal)
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
