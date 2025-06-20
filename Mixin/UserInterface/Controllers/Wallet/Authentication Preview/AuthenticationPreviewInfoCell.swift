import UIKit
import MixinServices

final class AuthenticationPreviewInfoCell: UITableViewCell {
    
    enum TrailingContent {
        case disclosure
        case plainTokenIcon(MixinTokenItem)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var labelStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var primaryLabel: UILabel!
    @IBOutlet weak var secondaryLabel: UILabel!
    
    @IBOutlet weak var contentTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    private let tokenIconDimension: CGFloat = 32
    
    private weak var disclosureImageView: UIImageView?
    private weak var tokenIconView: PlainTokenIconView?
    
    var trailingContent: TrailingContent? {
        didSet {
            switch trailingContent {
            case .disclosure:
                if disclosureImageView == nil {
                    let view = UIImageView(image: R.image.ic_selector_down())
                    view.tintColor = R.color.text_secondary()
                    contentStackView.addArrangedSubview(view)
                    disclosureImageView = view
                }
                tokenIconView?.removeFromSuperview()
            case .plainTokenIcon(let token):
                disclosureImageView?.removeFromSuperview()
                let view: PlainTokenIconView
                if let iconView = tokenIconView {
                    view = iconView
                } else {
                    let frame = CGRect(x: 0, y: 0, width: tokenIconDimension, height: tokenIconDimension)
                    view = PlainTokenIconView(frame: frame)
                    contentStackView.addArrangedSubview(view)
                    view.snp.makeConstraints { make in
                        make.width.height.equalTo(tokenIconDimension)
                    }
                }
                view.setIcon(token: token)
            case nil:
                disclosureImageView?.removeFromSuperview()
                tokenIconView?.removeFromSuperview()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        labelStackView.setCustomSpacing(8, after: captionLabel)
    }
    
    func setPrimaryLabel(usesBoldFont: Bool) {
        let weight: UIFont.Weight = usesBoldFont ? .medium : .regular
        primaryLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: weight),
                             adjustForContentSize: true)
    }
    
}
