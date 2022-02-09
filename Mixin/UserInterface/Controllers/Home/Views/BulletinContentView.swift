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
                titleLabel.text = R.string.localizable.home_bulletin_title_notification()
                descriptionLabel.text = R.string.localizable.home_bulletin_description_notification()
                continueButton.setTitle(R.string.localizable.action_settings(), for: .normal)
            case .emergencyContact:
                titleLabel.text = R.string.localizable.home_bulletin_title_emergency_contact()
                descriptionLabel.text = R.string.localizable.emergency_tip_before()
                continueButton.setTitle(R.string.localizable.action_settings(), for: .normal)
            case .initializePIN:
                titleLabel.text = R.string.localizable.home_bulletin_title_initialize_pin()
                descriptionLabel.text = R.string.localizable.home_bulletin_description_initialize_pin()
                continueButton.setTitle(R.string.localizable.action_continue(), for: .normal)
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
