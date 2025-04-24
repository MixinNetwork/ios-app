import UIKit

final class SendingDestinationCell: UITableViewCell {
    
    enum TitleTag {
        case free
        case privacyShield
    }
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    private weak var freeLabel: InsetLabel?
    private weak var privacyShieldImageView: UIImageView?
    
    var titleTag: TitleTag? = nil {
        didSet {
            load(titleTag: titleTag)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .clear
            return view
        }()
    }
    
    private func load(titleTag: TitleTag?) {
        switch titleTag {
        case .free:
            privacyShieldImageView?.removeFromSuperview()
            privacyShieldImageView = nil
            if freeLabel == nil {
                let label = InsetLabel()
                label.contentInset = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
                label.textColor = .white
                label.backgroundColor = R.color.background_tinted()
                label.layer.cornerRadius = 4
                label.layer.masksToBounds = true
                label.setFont(
                    scaledFor: .systemFont(ofSize: 12),
                    adjustForContentSize: true
                )
                label.text = R.string.localizable.free().uppercased()
                titleStackView.addArrangedSubview(label)
                self.freeLabel = label
            }
            titleStackView.spacing = 6
        case .privacyShield:
            freeLabel?.removeFromSuperview()
            freeLabel = nil
            if privacyShieldImageView == nil {
                let imageView = UIImageView(image: R.image.privacy_wallet())
                imageView.contentMode = .scaleAspectFit
                titleStackView.addArrangedSubview(imageView)
                imageView.snp.makeConstraints { make in
                    make.width.height.equalTo(18)
                }
                self.privacyShieldImageView = imageView
            }
            titleStackView.spacing = 4
        case .none:
            freeLabel?.removeFromSuperview()
            freeLabel = nil
            privacyShieldImageView?.removeFromSuperview()
            privacyShieldImageView = nil
        }
    }
    
}
