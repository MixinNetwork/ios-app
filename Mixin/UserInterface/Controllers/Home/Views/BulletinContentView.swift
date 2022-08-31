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
                titleLabel.text = R.string.localizable.turn_on_notifications()
                descriptionLabel.text = R.string.localizable.notification_content()
                continueButton.setTitle(R.string.localizable.settings(), for: .normal)
                closeButton.isHidden = false
            case .emergencyContact:
                titleLabel.text = R.string.localizable.emergency_contact()
                descriptionLabel.text = R.string.localizable.setting_emergency_content()
                continueButton.setTitle(R.string.localizable.settings(), for: .normal)
                closeButton.isHidden = false
            case .initializePIN:
                titleLabel.text = R.string.localizable.get_a_new_wallet()
                descriptionLabel.text = R.string.localizable.new_wallet_hint()
                continueButton.setTitle(R.string.localizable.continue(), for: .normal)
                closeButton.isHidden = false
            case .migrateToTIP:
                titleLabel.text = "升级 TIP"
                descriptionLabel.text = "PIN 基于去中心化密钥派生协议 Throttled Identity Protocol，阅读文档以了解更多。"
                continueButton.setTitle("Upgrade", for: .normal)
                closeButton.isHidden = true
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
