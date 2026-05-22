import UIKit

final class PerpetualMarketOpenPositionCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpetualMarketOpenPositionCell(_ cell: PerpetualMarketOpenPositionCell, requestManual page: PerpsManual.Page)
        func perpetualMarketOpenPositionCellAskToShare(_ cell: PerpetualMarketOpenPositionCell)
        func perpetualMarketOpenPositionCellRequestTakeProfit(_ cell: PerpetualMarketOpenPositionCell)
        func perpetualMarketOpenPositionCellRequestStopLoss(_ cell: PerpetualMarketOpenPositionCell)
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
    @IBOutlet weak var takeProfitContentLabel: InsetLabel!
    @IBOutlet weak var takeProfitButton: UIButton!
    @IBOutlet weak var takeProfitActivityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var stopLossTitleLabel: InsetLabel!
    @IBOutlet weak var stopLossContentStackView: UIStackView!
    @IBOutlet weak var stopLossContentLabel: InsetLabel!
    @IBOutlet weak var stopLossButton: UIButton!
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
        takeProfitContentLabel.contentInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 0)
        takeProfitButton.titleLabel?.adjustsFontForContentSizeCategory = true
        stopLossContentLabel.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        stopLossButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
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
    
    @IBAction func takeProfit(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellRequestTakeProfit(self)
    }
    
    @IBAction func stopLoss(_ sender: Any) {
        delegate?.perpetualMarketOpenPositionCellRequestStopLoss(self)
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
            takeProfitContentLabel.text = takeProfitPrice.formatted(viewModel.priceFormatStyle)
            takeProfitContentLabel.isHidden = false
            if var config = takeProfitButton.configuration {
                config.image = R.image.delete_perps_auto_closing()
                config.imagePadding = 0
                config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 10)
                config.attributedTitle = nil
                takeProfitButton.configuration = config
            }
        } else {
            takeProfitContentLabel.isHidden = true
            if var config = takeProfitButton.configuration {
                config.image = R.image.ic_accessory_disclosure()
                config.imagePadding = 10
                config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
                config.attributedTitle = AttributedString(
                    R.string.localizable.add(),
                    attributes: addAutoClosingAttributes
                )
                takeProfitButton.configuration = config
            }
        }
        if let stopLossPrice = viewModel.stopLossPrice {
            stopLossContentLabel.text = stopLossPrice.formatted(viewModel.priceFormatStyle)
            stopLossContentLabel.isHidden = false
            if var config = stopLossButton.configuration {
                config.image = R.image.delete_perps_auto_closing()
                config.imagePadding = 0
                config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 10)
                config.attributedTitle = nil
                stopLossButton.configuration = config
            }
        } else {
            stopLossContentLabel.isHidden = true
            if var config = stopLossButton.configuration {
                config.image = R.image.ic_accessory_disclosure()
                config.imagePadding = 10
                config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
                config.attributedTitle = AttributedString(
                    R.string.localizable.add(),
                    attributes: addAutoClosingAttributes
                )
                stopLossButton.configuration = config
            }
        }
        UIView.performWithoutAnimation {
            takeProfitButton.sizeToFit()
            stopLossButton.sizeToFit()
            autoClosingStackView.layoutIfNeeded()
        }
    }
    
    func updateTakeProfit(busy: Bool) {
        if busy {
            takeProfitActivityIndicator.startAnimating()
            takeProfitButton.isHidden = true
        } else {
            takeProfitActivityIndicator.stopAnimating()
            takeProfitButton.isHidden = false
        }
        UIView.performWithoutAnimation(autoClosingStackView.layoutIfNeeded)
    }
    
    func updateStopLoss(busy: Bool) {
        if busy {
            stopLossActivityIndicator.startAnimating()
            stopLossButton.isHidden = true
        } else {
            stopLossActivityIndicator.stopAnimating()
            stopLossButton.isHidden = false
        }
        UIView.performWithoutAnimation(autoClosingStackView.layoutIfNeeded)
    }
    
}
