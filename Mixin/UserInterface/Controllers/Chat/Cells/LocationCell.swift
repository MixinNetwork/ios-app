import UIKit
import MixinServices

class LocationCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconBackgroundImageView: UIImageView!
    @IBOutlet weak var iconImageView: RenderingModeSwitchableImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    var showsNavigationImageView = false {
        didSet {
            if showsNavigationImageView {
                if navigationImageView.superview == nil {
                    contentStackView.addArrangedSubview(navigationImageView)
                }
            } else {
                if let view = navigationImageViewIfLoaded {
                    contentStackView.removeArrangedSubview(view)
                }
            }
        }
    }
    
    private lazy var navigationImageView: UIImageView = {
        let view = UIImageView(image: R.image.conversation.ic_navigation())
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        navigationImageViewIfLoaded = view
        return view
    }()
    
    private weak var navigationImageViewIfLoaded: UIImageView?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }
    
    func render(location: Location) {
        iconBackgroundImageView.isHidden = false
        iconImageView.renderingMode = .alwaysTemplate
        iconImageView.contentMode = .scaleAspectFill
//        iconImageView.sd_setImage(with: location.iconUrl, completed: nil)
        titleLabel.text = location.name
        subtitleLabel.text = location.address
    }
    
    func renderAsUserLocation(accuracy: String) {
        renderAsUserRelatedLocation()
        titleLabel.text = R.string.localizable.chat_location_send_current()
        subtitleLabel.text = R.string.localizable.chat_location_accuracy(accuracy)
    }
    
    func renderAsUserPickedLocation(address: String?) {
        renderAsUserRelatedLocation()
        titleLabel.text = R.string.localizable.chat_location_send_user_picked()
        subtitleLabel.text = address ?? R.string.localizable.chat_location_reverse_geocode_processing()
    }
    
    private func renderAsUserRelatedLocation() {
        iconBackgroundImageView.isHidden = true
        iconImageView.renderingMode = .alwaysOriginal
        iconImageView.contentMode = .center
        iconImageView.image = R.image.conversation.ic_location_user()
    }
    
}
