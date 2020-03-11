import UIKit
import MixinServices

class LocationCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconBackgroundImageView: UIImageView!
    @IBOutlet weak var iconImageView: RenderingModeSwitchableImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }
    
    func render(location: FoursquareLocation) {
        iconBackgroundImageView.isHidden = false
        iconImageView.renderingMode = .alwaysTemplate
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.sd_setImage(with: location.iconUrl, completed: nil)
        titleLabel.text = location.name
        subtitleLabel.text = location.address
    }
    
    func renderAsCurrentLocation(accuracy: String) {
        iconBackgroundImageView.isHidden = true
        iconImageView.renderingMode = .alwaysOriginal
        iconImageView.contentMode = .center
        iconImageView.image = R.image.conversation.ic_location_user()
        titleLabel.text = R.string.localizable.chat_location_send_current()
        subtitleLabel.text = R.string.localizable.chat_location_accuracy(accuracy)
    }
    
}
