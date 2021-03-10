import UIKit

class BulletinContentView: UIView {
    
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    var content: BulletinContent? = nil {
        didSet {
            switch content {
            case .notification:
                titleLabel.text = R.string.localizable.home_bulletin_title_notification()
                descriptionLabel.text = R.string.localizable.home_bulletin_description_notification()
            case .emergencyContact:
                titleLabel.text = R.string.localizable.home_bulletin_title_emergency_contact()
                descriptionLabel.text = R.string.localizable.emergency_tip_before()
            case .none:
                titleLabel.text = nil
                descriptionLabel.text = nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let closeImage = R.image.ic_announcement_close()!.withRenderingMode(.alwaysTemplate)
        closeButton.setImage(closeImage, for: .normal)
    }
    
}
