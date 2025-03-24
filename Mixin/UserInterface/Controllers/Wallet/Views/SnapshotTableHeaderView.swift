import UIKit

final class SnapshotTableHeaderView: InfiniteTopView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    @IBOutlet weak var iconViewDimensionConstraint: ScreenHeightCompatibleLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountLabel.setFont(scaledFor: .condensed(size: 34), adjustForContentSize: true)
        symbolLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        if ScreenHeight.current >= .extraLong {
            iconView.badgeIconDiameter = 28
            iconView.badgeOutlineWidth = 4
            contentStackView.spacing = 2
        }
    }
    
}
