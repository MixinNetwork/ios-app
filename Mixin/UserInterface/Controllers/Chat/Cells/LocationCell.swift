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
                navigationImageViewIfLoaded?.removeFromSuperview()
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        iconImageView.renderingMode = .alwaysTemplate
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }
    
    func render(location: Location) {
        if let url = location.iconUrl {
            iconBackgroundImageView.image = R.image.conversation.bg_location_category()
            iconImageView.isHidden = false
            iconImageView.sd_setImage(with: url, completed: nil)
        } else {
            renderAsUserRelatedLocation()
        }
        titleLabel.text = location.name ?? R.string.localizable.unnamed_location()
        subtitleLabel.text = location.address
    }
    
    func renderAsUserLocation(accuracy: String) {
        renderAsUserRelatedLocation()
        titleLabel.text = R.string.localizable.send_your_current_location()
        subtitleLabel.text = R.string.localizable.location_accuracy_to(accuracy)
    }
    
    func renderAsUserPickedLocation(address: String?) {
        renderAsUserRelatedLocation()
        titleLabel.text = R.string.localizable.send_this_location()
        subtitleLabel.text = address ?? R.string.localizable.locating()
    }
    
    private func renderAsUserRelatedLocation() {
        iconImageView.isHidden = true
        iconBackgroundImageView.image = R.image.conversation.ic_location_user()
    }
    
}
