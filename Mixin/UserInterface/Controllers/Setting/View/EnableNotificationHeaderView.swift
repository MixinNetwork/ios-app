import UIKit

final class EnableNotificationHeaderView: UIView {

    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var enableNotificationButton: UIButton!
    
    override func awakeFromNib() {
        titleLabel.text = R.string.localizable.enable_push_notification()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .semibold),
            adjustForContentSize: true
        )
        descriptionLabel.text = R.string.localizable.notification_content()
        if var config = enableNotificationButton.configuration {
            let attributes: AttributeContainer = {
                var container = AttributeContainer()
                container.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
                container.foregroundColor = .white
                return container
            }()
            config.attributedTitle = AttributedString(
                R.string.localizable.enable_notifications(),
                attributes: attributes
            )
            enableNotificationButton.configuration = config
        }
        enableNotificationButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    private var lastLayoutWidth: CGFloat?
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let sizeToFitText = CGSize(
            width: size.width - 100,
            height: UIView.layoutFittingExpandedSize.height
        )
        let titleHeight = titleLabel.sizeThatFits(sizeToFitText).height
        let descriptionHeight = descriptionLabel.sizeThatFits(sizeToFitText).height
        let sizeToFitButton = CGSize(
            width: size.width - 72,
            height: UIView.layoutFittingExpandedSize.height
        )
        let buttonHeight = enableNotificationButton.sizeThatFits(sizeToFitButton).height
        let height = 30 + 70 + 12 + titleHeight + titleStackView.spacing + descriptionHeight + 20 + buttonHeight + 20
        return CGSize(width: size.width, height: ceil(height))
    }
    
    func sizeToFit(tableView: UITableView) {
        assert(tableView.tableHeaderView == self)
        let width = tableView.bounds.width
        guard width != lastLayoutWidth else {
            return
        }
        let sizeToFit = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        let height = sizeThatFits(sizeToFit).height
        frame.size = CGSize(width: width, height: height)
        tableView.tableHeaderView = self
        lastLayoutWidth = width
    }
    
}
