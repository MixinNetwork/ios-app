import UIKit

final class PerpetualMarketOpenPositionCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpetualMarketOpenPositionCell(_ cell: PerpetualMarketOpenPositionCell, requestManual page: PerpsManual.Page)
        func perpetualMarketOpenPositionCellAskToShare(_ cell: PerpetualMarketOpenPositionCell)
        func perpetualMarketOpenPositionCellRequestAddTakeProfit(_ cell: PerpetualMarketOpenPositionCell)
        func perpetualMarketOpenPositionCellRequestDeleteTakeProfit(_ cell: PerpetualMarketOpenPositionCell)
        func perpetualMarketOpenPositionCellRequestAddStopLoss(_ cell: PerpetualMarketOpenPositionCell)
        func perpetualMarketOpenPositionCellRequestDeleteStopLoss(_ cell: PerpetualMarketOpenPositionCell)
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
    
    @IBOutlet weak var autoClosingStackView: UIStackView!
    
    @IBOutlet weak var takeProfitTitleLabel: InsetLabel!
    @IBOutlet weak var takeProfitContentStackView: UIStackView!
    @IBOutlet weak var takeProfitEnabledStackView: UIStackView!
    @IBOutlet weak var takeProfitPriceLabel: InsetLabel!
    @IBOutlet weak var deleteTakeProfitButton: UIButton!
    @IBOutlet weak var addTakeProfitButton: UIButton!
    @IBOutlet weak var takeProfitActivityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var stopLossTitleLabel: InsetLabel!
    @IBOutlet weak var stopLossContentStackView: UIStackView!
    @IBOutlet weak var stopLossEnabledStackView: UIStackView!
    @IBOutlet weak var stopLossPriceLabel: InsetLabel!
    @IBOutlet weak var deleteStopLossButton: UIButton!
    @IBOutlet weak var addStopLossButton: UIButton!
    @IBOutlet weak var stopLossActivityIndicator: ActivityIndicatorView!
    
    weak var delegate: Delegate?
    
    private var addAutoClosingAttributes: AttributeContainer = {
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        return attributes
    }()
    
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
        takeProfitTitleLabel.contentInset.left = 10
        takeProfitPriceLabel.contentInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 0)
        addTakeProfitButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.add(),
            attributes: addAutoClosingAttributes
        )
        addTakeProfitButton.titleLabel?.adjustsFontForContentSizeCategory = true
        stopLossPriceLabel.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        addStopLossButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.add(),
            attributes: addAutoClosingAttributes
        )
        addStopLossButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        titleLabel.text = R.string.localizable.position()
        pnlTitleLabel.text = R.string.localizable.pnl().uppercased()
        directionTitleLabel.text = R.string.localizable.direction().uppercased()
        orderValueTitleLabel.text = R.string.localizable.position_size().uppercased()
        marginTitleLabel.text = R.string.localizable.margin().uppercased()
        entryPriceTitleLabel.text = R.string.localizable.entry_price().uppercased()
        liquidationPriceTitleLabel.text = R.string.localizable.liquidation_price().uppercased()
        takeProfitTitleLabel.text = R.string.localizable.take_profit().uppercased()
        stopLossTitleLabel.text = R.string.localizable.stop_loss().uppercased()
        
        takeProfitActivityIndicator.style = .custom(diameter: 10, lineWidth: 2)
        stopLossActivityIndicator.style = .custom(diameter: 10, lineWidth: 2)
    }
    
    @IBAction func requestShare(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellAskToShare(self)
    }
    
    @IBAction func questionAboutSize(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCell(self, requestManual: .size)
    }
    
    @IBAction func questionAboutLiquidation(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCell(self, requestManual: .liquidation)
    }
    
    @IBAction func questionAboutAutoClosing(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCell(self, requestManual: .autoClosing)
    }
    
    @IBAction func addTakeProfit(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellRequestAddTakeProfit(self)
    }
    
    @IBAction func deleteTakeProfit(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellRequestDeleteTakeProfit(self)
    }
    
    @IBAction func addStopLoss(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellRequestAddStopLoss(self)
    }
    
    @IBAction func deleteStopLoss(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellRequestDeleteStopLoss(self)
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        pnlContentLabel.text = viewModel.pnlWithROE
        pnlContentLabel.marketColor = viewModel.pnlColor
        switch viewModel.side {
        case .long:
            directionSideLabel.text = R.string.localizable.long()
            directionSideLabel.backgroundColor = MarketColor.rising.uiColor
        case .short:
            directionSideLabel.text = R.string.localizable.short()
            directionSideLabel.backgroundColor = MarketColor.falling.uiColor
        }
        directionLeverageLabel.text = viewModel.leverage
        orderValueContentLabel.text = {
            if let orderValueInFiatMoney = viewModel.orderValueInFiatMoney {
                viewModel.orderValueInToken + " (" + orderValueInFiatMoney + ")"
            } else {
                viewModel.orderValueInToken
            }
        }()
        marginContentLabel.text = viewModel.margin
        entryPriceContentLabel.text = viewModel.entryPrice
        liquidationPriceContentLabel.text = viewModel.liquidationPrice
        if let takeProfitPrice = viewModel.takeProfitPrice {
            takeProfitEnabledStackView.isHidden = false
            takeProfitPriceLabel.text = takeProfitPrice.formatted(viewModel.priceFormatStyle)
            deleteTakeProfitButton.isHidden = false
            addTakeProfitButton.isHidden = true
        } else {
            takeProfitEnabledStackView.isHidden = true
            deleteTakeProfitButton.isHidden = true
            addTakeProfitButton.isHidden = false
            
            // Otherwise the button sizes title label to width of 1
            // Verified on iOS 18.7
            addTakeProfitButton.invalidateIntrinsicContentSize()
        }
        if let stopLossPrice = viewModel.stopLossPrice {
            stopLossEnabledStackView.isHidden = false
            stopLossPriceLabel.text = stopLossPrice.formatted(viewModel.priceFormatStyle)
            deleteStopLossButton.isHidden = false
            addStopLossButton.isHidden = true
        } else {
            stopLossEnabledStackView.isHidden = true
            deleteStopLossButton.isHidden = true
            addStopLossButton.isHidden = false
            
            // Otherwise the button sizes title label to width of 1
            // Verified on iOS 18.7
            addStopLossButton.invalidateIntrinsicContentSize()
        }
    }
    
    func updateTakeProfit(busy: Bool) {
        if busy {
            takeProfitActivityIndicator.startAnimating()
            takeProfitEnabledStackView.isHidden = true
            deleteTakeProfitButton.isHidden = true
            addTakeProfitButton.isHidden = true
        } else {
            takeProfitActivityIndicator.stopAnimating()
        }
        UIView.performWithoutAnimation(takeProfitContentStackView.layoutIfNeeded)
    }
    
    func updateStopLoss(busy: Bool) {
        if busy {
            stopLossActivityIndicator.startAnimating()
            stopLossEnabledStackView.isHidden = true
            deleteStopLossButton.isHidden = true
            addStopLossButton.isHidden = true
        } else {
            stopLossActivityIndicator.stopAnimating()
        }
        UIView.performWithoutAnimation(stopLossContentStackView.layoutIfNeeded)
    }
    
}
