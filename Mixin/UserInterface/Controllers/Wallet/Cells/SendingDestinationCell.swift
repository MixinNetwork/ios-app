import UIKit

final class SendingDestinationCell: UITableViewCell {
    
    enum TitleTag {
        case free
        case privacyShield
        case apy(String)
    }
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    private weak var tagLabel: InsetLabel?
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
            let tagLabel: InsetLabel
            if let label = self.tagLabel {
                tagLabel = label
            } else {
                tagLabel = makeTagLabel()
                titleStackView.addArrangedSubview(tagLabel)
                self.tagLabel = tagLabel
            }
            tagLabel.backgroundColor = R.color.background_tinted()
            tagLabel.text = R.string.localizable.free().uppercased()
            titleStackView.spacing = 6
        case .privacyShield:
            tagLabel?.removeFromSuperview()
            tagLabel = nil
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
        case .apy(let apy):
            privacyShieldImageView?.removeFromSuperview()
            privacyShieldImageView = nil
            let tagLabel: InsetLabel
            if let label = self.tagLabel {
                tagLabel = label
            } else {
                tagLabel = makeTagLabel()
                titleStackView.addArrangedSubview(tagLabel)
                self.tagLabel = tagLabel
            }
            tagLabel.backgroundColor = R.color.market_green()
            tagLabel.text = apy
            titleStackView.spacing = 6
        case .none:
            tagLabel?.removeFromSuperview()
            tagLabel = nil
            privacyShieldImageView?.removeFromSuperview()
            privacyShieldImageView = nil
        }
    }
    
    private func makeTagLabel() -> InsetLabel {
        let label = InsetLabel()
        label.contentInset = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        label.textColor = .white
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.setFont(
            scaledFor: .systemFont(ofSize: 12),
            adjustForContentSize: true
        )
        return label
    }
    
}
