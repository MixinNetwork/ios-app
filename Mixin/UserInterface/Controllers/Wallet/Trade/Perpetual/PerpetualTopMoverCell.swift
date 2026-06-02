import UIKit

final class PerpetualTopMoverCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: PlainTokenIconView!
    @IBOutlet weak var leverageLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leverageLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        leverageLabel.font = .condensed(size: 12)
        leverageLabel.layer.cornerRadius = 4
        leverageLabel.layer.masksToBounds = true
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func load(viewModel: PerpetualMarketViewModel) {
        iconImageView.setIcon(tokenIconURL: viewModel.iconURL)
        leverageLabel.text = viewModel.leverage
        symbolLabel.text = viewModel.market.tokenSymbol
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
    }
    
}
