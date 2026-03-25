import UIKit

final class PerpetualInactivePositionCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var leverageLabel: LeverageLabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leverageLabel.setFont(
            scaledFor: .condensed(size: 12),
            adjustForContentSize: true
        )
        for label: UILabel in [valueLabel, changeLabel] {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        titleLabel.text = viewModel.directionWithSymbol
        leverageLabel.text = viewModel.leverageMultiplier
        valueLabel.text = viewModel.orderValueInToken
        switch viewModel.type {
        case .open:
            leverageLabel.color = .neutral
            changeLabel.text = R.string.localizable.perp_state_opening()
            changeLabel.textColor = R.color.text_tertiary()
        case .closed:
            switch viewModel.side {
            case .long:
                leverageLabel.color = .long
            case .short:
                leverageLabel.color = .short
            }
            changeLabel.text = viewModel.pnlWithROE
            changeLabel.marketColor = viewModel.pnlColor
        }
    }
    
}
