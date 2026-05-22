import UIKit

final class PerpetualPositionHeaderCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var directionLabel: InsetLabel!
    @IBOutlet weak var actionView: PillActionView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.font = .condensed(size: 34)
        symbolLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 6, right: 0)
        directionLabel.contentInset = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        directionLabel.layer.cornerRadius = 4
        directionLabel.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualActivityViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        titleLabel.text = viewModel.quantity
        symbolLabel.text = viewModel.tokenSymbol
        symbolLabel.isHidden = false
        switch viewModel.status {
        case .normal:
            switch viewModel.side {
            case .long:
                let color = MarketColor.rising.uiColor
                directionLabel.backgroundColor = color.withAlphaComponent(0.2)
                directionLabel.textColor = color
            case .short:
                let color = MarketColor.falling.uiColor
                directionLabel.backgroundColor = color.withAlphaComponent(0.2)
                directionLabel.textColor = color
            }
        case .rejected:
            directionLabel.backgroundColor = R.color.background_quaternary()
            directionLabel.textColor = R.color.text_tertiary()
        }
        directionLabel.text = switch viewModel.side {
        case .long:
            R.string.localizable.long_asset(viewModel.leverage)
        case .short:
            R.string.localizable.short_asset(viewModel.leverage)
        }
        if viewModel.actions.isEmpty {
            actionView.isHidden = true
        } else {
            actionView.actions = viewModel.actions.map { $0.asPillAction() }
            actionView.isHidden = false
        }
    }
    
}
