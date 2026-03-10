import UIKit

final class PerpetualClosedPositionCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var leverageLabel: LeverageLabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        changeLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        titleLabel.text = viewModel.directionWithSymbol
        switch viewModel.leverage {
        case .long(let value):
            leverageLabel.text = value
            leverageLabel.color = .long
        case .short(let value):
            leverageLabel.text = value
            leverageLabel.color = .short
        }
        valueLabel.text = viewModel.orderValueInToken
        changeLabel.text = viewModel.pnl
        changeLabel.marketColor = viewModel.pnlColor
    }
    
}
