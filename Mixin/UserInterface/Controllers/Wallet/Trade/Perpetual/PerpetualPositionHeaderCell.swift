import UIKit

final class PerpetualPositionHeaderCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var directionLabel: InsetLabel!
    @IBOutlet weak var actionView: PillActionView!
    
    @IBOutlet weak var titleTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var directionTopConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        symbolLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 6, right: 0)
        directionLabel.contentInset = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        directionLabel.layer.cornerRadius = 4
        directionLabel.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        switch viewModel.state {
        case .open:
            titleTopConstraint.constant = 15
            directionTopConstraint.constant = 16
            titleLabel.text = viewModel.directionWithSymbol
            titleLabel.font = .systemFont(ofSize: 24, weight: .medium)
            symbolLabel.text = nil
            symbolLabel.isHidden = true
        case .closed:
            titleTopConstraint.constant = 7
            directionTopConstraint.constant = 10
            titleLabel.text = viewModel.quantity
            titleLabel.font = .condensed(size: 34)
            symbolLabel.text = viewModel.tokenSymbol
            symbolLabel.isHidden = false
        }
        switch viewModel.side {
        case .long:
            let color = MarketColor.rising.uiColor
            directionLabel.text = R.string.localizable.long_asset(viewModel.leverageMultiplier)
            directionLabel.backgroundColor = color.withAlphaComponent(0.2)
            directionLabel.textColor = color
        case .short:
            let color = MarketColor.falling.uiColor
            directionLabel.text = R.string.localizable.short_asset(viewModel.leverageMultiplier)
            directionLabel.backgroundColor = color.withAlphaComponent(0.2)
            directionLabel.textColor = color
        }
        actionView.actions = viewModel.actions.map { $0.asPillAction() }
    }
    
}
