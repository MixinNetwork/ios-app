import UIKit

final class PerpetualMarketOpenPositionCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpetualMarketOpenPositionCellQuestionAboutSize(_ cell: PerpetualMarketOpenPositionCell)
        func perpetualMarketOpenPositionCellAskToShare(_ cell: PerpetualMarketOpenPositionCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var pnlTitleLabel: UILabel!
    @IBOutlet weak var pnlContentLabel: MarketColoredLabel!
    
    @IBOutlet weak var directionTitleLabel: UILabel!
    @IBOutlet weak var directionSideLabel: InsetLabel!
    @IBOutlet weak var directionLeverageLabel: UILabel!
    
    @IBOutlet weak var orderValueTitleLabel: UILabel!
    @IBOutlet weak var orderValueContentLabel: UILabel!
    
    @IBOutlet weak var marginTitleLabel: UILabel!
    @IBOutlet weak var marginContentLabel: UILabel!
    
    @IBOutlet weak var entryPriceTitleLabel: UILabel!
    @IBOutlet weak var entryPriceContentLabel: UILabel!
    
    @IBOutlet weak var liquidationPriceTitleLabel: UILabel!
    @IBOutlet weak var liquidationPriceContentLabel: UILabel!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        for label: UILabel in [pnlContentLabel, directionLeverageLabel] {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14, weight: .medium),
                adjustForContentSize: true
            )
        }
        directionSideLabel.contentInset = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        directionSideLabel.layer.cornerRadius = 6
        directionSideLabel.layer.masksToBounds = true
        let contentLabels: [UILabel] = [
            orderValueContentLabel,
            marginContentLabel,
            entryPriceContentLabel,
            liquidationPriceContentLabel,
        ]
        for label in contentLabels {
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
        }
    }
    
    @IBAction func questionAboutSize(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellQuestionAboutSize(self)
    }
    
    @IBAction func requestShare(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellAskToShare(self)
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        titleLabel.text = R.string.localizable.position()
        pnlTitleLabel.text = R.string.localizable.pnl().uppercased()
        pnlContentLabel.text = viewModel.pnlWithROE
        pnlContentLabel.marketColor = viewModel.pnlColor
        directionTitleLabel.text = R.string.localizable.direction().uppercased()
        switch viewModel.side {
        case .long:
            directionSideLabel.text = R.string.localizable.long()
            directionSideLabel.backgroundColor = MarketColor.rising.uiColor
        case .short:
            directionSideLabel.text = R.string.localizable.short()
            directionSideLabel.backgroundColor = MarketColor.falling.uiColor
        }
        directionLeverageLabel.text = viewModel.leverageMultiplier
        orderValueTitleLabel.text = R.string.localizable.position_size().uppercased()
        orderValueContentLabel.text = viewModel.orderValueInToken
        marginTitleLabel.text = R.string.localizable.margin().uppercased()
        marginContentLabel.text = viewModel.margin
        entryPriceTitleLabel.text = R.string.localizable.entry_price().uppercased()
        entryPriceContentLabel.text = viewModel.entryPrice
        liquidationPriceTitleLabel.text = R.string.localizable.liquidation_price().uppercased()
        liquidationPriceContentLabel.text = viewModel.liquidationPrice
    }
    
}
