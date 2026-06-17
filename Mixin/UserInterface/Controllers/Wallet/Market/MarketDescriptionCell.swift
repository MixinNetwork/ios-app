import UIKit

final class MarketDescriptionCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func marketDescriptionCellDidSelectMore(_ cell: MarketDescriptionCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var moreButton: UIButton!
    
    weak var delegate: Delegate?
    
    var isExpanded = false {
        didSet {
            if isExpanded {
                contentLabel.numberOfLines = 0
                moreButton.isHidden = true
                gradientLayer.isHidden = true
            } else {
                contentLabel.numberOfLines = 3
                moreButton.isHidden = false
                gradientLayer.isHidden = false
            }
        }
    }
    
    private let gradientWidth: CGFloat = 40
    private let gradientSpacing: CGFloat = 10
    private let gradientLayer = CAGradientLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.about()
        if var config = moreButton.configuration {
            config.background.backgroundInsets = NSDirectionalEdgeInsets(
                top: config.contentInsets.top,
                leading: max(0, config.contentInsets.leading - gradientSpacing),
                bottom: config.contentInsets.bottom,
                trailing: config.contentInsets.trailing
            )
            var attributes = AttributeContainer()
            attributes.font = UIFont.preferredFont(forTextStyle: .footnote)
            config.attributedTitle = AttributedString(
                R.string.localizable.more(),
                attributes: attributes
            )
            moreButton.configuration = config
            moreButton.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        contentView.layer.addSublayer(gradientLayer)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations = [0, 0.3917, 1]
        updateColors()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let label = moreButton.titleLabel {
            let moreLabelFrame = label.convert(label.bounds, to: contentView)
            gradientLayer.frame = CGRect(
                x: moreLabelFrame.origin.x - gradientSpacing - gradientWidth,
                y: moreLabelFrame.origin.y,
                width: gradientWidth,
                height: moreLabelFrame.height
            )
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }
    
    @IBAction func showMore(_ sender: Any) {
        delegate?.marketDescriptionCellDidSelectMore(self)
    }
    
    private func updateColors() {
        gradientLayer.colors = [0, 0.6024, 1].map {
            R.color.background_secondary()!.withAlphaComponent($0).cgColor
        }
    }
    
}
