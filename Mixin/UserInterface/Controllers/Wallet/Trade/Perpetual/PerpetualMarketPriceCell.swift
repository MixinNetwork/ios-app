import UIKit
import MixinServices

final class PerpetualMarketPriceCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpetualMarketPriceCell(_ cell: PerpetualMarketPriceCell, didSelectTimeFrame timeFrame: PerpetualTimeFrame)
    }
    
    enum Chart {
        case unavailable
        case loading
        case candles([PerpetualCandleViewModel])
    }
    
    @IBOutlet weak var priceSelectorButton: UIButton!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var chartView: CandlestickChartView!
    @IBOutlet weak var loadingIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var timeFrameScrollView: UIScrollView!
    @IBOutlet weak var timeFrameStackView: UIStackView!
    
    weak var delegate: Delegate?
    
    private weak var unavailableView: UIView?
    
    private var chart: Chart?
    private var timeFrame: PerpetualTimeFrame = .oneMinute
    private var priceScale: Int?
    private var lastPrice: Decimal?
    private var marketID: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        priceSelectorButton.showsMenuAsPrimaryAction = true
        priceSelectorButton.configuration?.titleTextAttributesTransformer = .init { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14)
            )
            outgoing.foregroundColor = R.color.text_secondary()
            return outgoing
        }
        priceSelectorButton.titleLabel?.adjustsFontForContentSizeCategory = true
        priceLabel.setFont(
            scaledFor: .systemFont(ofSize: 22, weight: .medium),
            adjustForContentSize: true
        )
        changeLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        chartView.labels = .localized
        timeFrameScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        for (i, timeFrame) in PerpetualTimeFrame.allCases.enumerated() {
            var config: UIButton.Configuration = .filled()
            let title = switch timeFrame {
            case .oneMinute:
                R.string.localizable.minutes_count_short(1)
            case .fiveMinutes:
                R.string.localizable.minutes_count_short(5)
            case .fifteenMinutes:
                R.string.localizable.minutes_count_short(15)
            case .oneHour:
                R.string.localizable.hours_count_short(1).uppercased()
            case .fourHours:
                R.string.localizable.hours_count_short(4).uppercased()
            case .oneDay:
                R.string.localizable.days_count_short(1).uppercased()
            case .oneWeek:
                R.string.localizable.weeks_count_short(1)
            }
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14)
            )
            config.attributedTitle = AttributedString(title, attributes: attributes)
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
            let button = UIButton(configuration: config)
            button.configurationUpdateHandler = { button in
                guard var config = button.configuration else {
                    return
                }
                if button.isSelected {
                    config.baseForegroundColor = R.color.text()
                    config.baseBackgroundColor = R.color.background_quaternary()
                } else {
                    config.baseForegroundColor = R.color.text_quaternary()
                    config.baseBackgroundColor = .clear
                }
                button.configuration = config
            }
            button.tag = i
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            timeFrameStackView.addArrangedSubview(button)
            button.addTarget(self, action: #selector(changeTimeFrame(_:)), for: .touchUpInside)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
        chartView.endInteraction()
        chart = nil
        marketID = nil
    }
    
    func load(viewModel: PerpetualMarketViewModel) {
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
    }
    
    func loadPrice(title: String, content: String) {
        priceSelectorButton.configuration?.title = title
        priceLabel.text = content
    }
    
    func load(
        chart: Chart,
        marketID: String,
        timeFrame: PerpetualTimeFrame,
        viewportState: CandleChartViewportState,
        priceScale: Int,
        lastPrice: Decimal,
    ) {
        self.chart = chart
        self.marketID = marketID
        self.timeFrame = timeFrame
        self.priceScale = priceScale
        self.lastPrice = lastPrice
        switch chart {
        case .candles(let candles) where candles.isEmpty:
            fallthrough
        case .unavailable:
            viewportState.liveWick = nil
            showUnavailableView()
            loadingIndicatorView.stopAnimating()
        case .loading:
            hideUnavailableView()
            loadingIndicatorView.startAnimating()
        case .candles(let candles):
            configureChart(candles: candles, marketID: marketID, viewportState: viewportState)
            hideUnavailableView()
            loadingIndicatorView.stopAnimating()
        }
    }
    
    // Partial refresh for market polling, keeps viewport state and in-flight gestures untouched
    func updatePrice(viewModel: PerpetualMarketViewModel) {
        let marketID = viewModel.market.marketID
        guard marketID == self.marketID else {
            return
        }
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
        let lastPrice = viewModel.decimalLastPrice
        let priceScale = viewModel.market.priceScale
        guard lastPrice != self.lastPrice || priceScale != self.priceScale else {
            return
        }
        self.lastPrice = lastPrice
        self.priceScale = priceScale
        switch chart {
        case .candles(let candles) where !candles.isEmpty:
            configureChart(candles: candles, marketID: marketID, viewportState: chartView.viewportState)
        case .candles, .unavailable, .loading, .none:
            break
        }
    }
    
    func setTimeFrame(frame: PerpetualTimeFrame) {
        guard let index = PerpetualTimeFrame.allCases.firstIndex(of: frame) else {
            return
        }
        setTimeFrameSelection(index: index)
    }
    
    @objc private func changeTimeFrame(_ sender: UIButton) {
        setTimeFrameSelection(index: sender.tag)
        let frame = PerpetualTimeFrame.allCases[sender.tag]
        delegate?.perpetualMarketPriceCell(self, didSelectTimeFrame: frame)
    }
    
    private func configureChart(
        candles: [PerpetualCandleViewModel],
        marketID: String,
        viewportState: CandleChartViewportState,
    ) {
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let liveCandles = PerpetualCandleViewModel.withLivePrice(
            candles: candles,
            lastPrice: lastPrice,
            timeFrame: timeFrame,
            nowMillis: nowMillis,
        )
        let (wickedCandles, wick) = PerpetualCandleViewModel.withLiveWick(
            candles: liveCandles,
            marketID: marketID,
            timeFrame: timeFrame,
            nowMillis: nowMillis,
            cachedWick: viewportState.liveWick,
        )
        viewportState.liveWick = wick
        chartView.configure(
            candles: wickedCandles,
            timeFrame: timeFrame,
            latestPrice: lastPrice,
            priceFormatMode: .decimal(priceScale: priceScale),
            viewportState: viewportState,
            animated: true
        )
    }
    
    private func setTimeFrameSelection(index: Int) {
        for case let button as UIButton in timeFrameStackView.arrangedSubviews {
            button.isSelected = button.tag == index
        }
    }
    
    private func showUnavailableView() {
        let unavailableView: UIView
        if let view = self.unavailableView {
            unavailableView = view
        } else {
            unavailableView = PriceDataUnavailableView()
            contentView.addSubview(unavailableView)
            unavailableView.snp.makeConstraints { make in
                make.edges.equalTo(chartView)
            }
            self.unavailableView = unavailableView
        }
        unavailableView.isHidden = false
        timeFrameStackView.alpha = 0
    }
    
    private func hideUnavailableView() {
        unavailableView?.isHidden = true
        timeFrameStackView.alpha = 1
    }
    
}
