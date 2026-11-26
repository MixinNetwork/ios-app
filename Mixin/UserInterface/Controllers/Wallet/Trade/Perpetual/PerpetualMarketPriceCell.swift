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
    private var timeFrameDividers: [UIView] = []
    private var timeFrameIndicatorConstraints: [NSLayoutConstraint] = []
    let timeFrameIndicatorView = UIView()
    
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
        timeFrameScrollView.backgroundColor = R.color.background_secondary()
        timeFrameScrollView.layer.cornerRadius = 21
        timeFrameIndicatorView.backgroundColor = R.color.background()
        timeFrameIndicatorView.layer.cornerRadius = 18
        timeFrameIndicatorView.isHidden = true
        timeFrameIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        timeFrameScrollView.insertSubview(timeFrameIndicatorView, at: 0)
        NSLayoutConstraint.activate([
            timeFrameIndicatorView.topAnchor.constraint(equalTo: timeFrameScrollView.topAnchor, constant: 3),
            timeFrameIndicatorView.bottomAnchor.constraint(equalTo: timeFrameScrollView.bottomAnchor, constant: -3),
        ])
        timeFrameStackView.isLayoutMarginsRelativeArrangement = true
        timeFrameStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3)
        for (i, timeFrame) in PerpetualTimeFrame.allCases.enumerated() {
            if i > 0 {
                let divider = UIView()
                divider.backgroundColor = R.color.time_frame_divider()
                divider.translatesAutoresizingMaskIntoConstraints = false
                let container = UIView()
                container.addSubview(divider)
                container.widthAnchor.constraint(equalToConstant: 1).isActive = true
                NSLayoutConstraint.activate([
                    divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    divider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    divider.heightAnchor.constraint(equalToConstant: 12),
                ])
                container.setContentHuggingPriority(.required, for: .horizontal)
                timeFrameStackView.addArrangedSubview(container)
                timeFrameDividers.append(divider)
            }
            var config: UIButton.Configuration = .plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
            config.background.backgroundColor = .clear
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
            let button = UIButton(configuration: config)
            button.configurationUpdateHandler = { button in
                guard var config = button.configuration else {
                    return
                }
                var attributes = AttributeContainer()
                attributes.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 14, weight: button.isSelected ? .semibold : .medium)
                )
                attributes.foregroundColor = R.color.text()
                config.attributedTitle = AttributedString(title, attributes: attributes)
                button.configuration = config
            }
            button.tag = i
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.defaultLow, for: .horizontal)
            timeFrameStackView.addArrangedSubview(button)
            button.addTarget(self, action: #selector(changeTimeFrame(_:)), for: .touchUpInside)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
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
        timeFrame: PerpetualTimeFrame,
        viewportState: CandleChartViewportState,
        priceScale: Int,
        lastPrice: Decimal
    ) {
        self.chart = chart
        self.timeFrame = timeFrame
        self.priceScale = priceScale
        self.lastPrice = lastPrice
        switch chart {
        case .candles(let candles) where candles.isEmpty:
            fallthrough
        case .unavailable:
            showUnavailableView()
            loadingIndicatorView.stopAnimating()
        case .loading:
            hideUnavailableView()
            loadingIndicatorView.startAnimating()
        case .candles(let candles):
            configureChart(candles: candles, viewportState: viewportState)
            hideUnavailableView()
            loadingIndicatorView.stopAnimating()
        }
    }
    
    // Partial refresh for market polling, keeps viewport state and in-flight gestures untouched
    func updatePrice(viewModel: PerpetualMarketViewModel) {
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
        let lastPrice = viewModel.decimalLastPrice
        let priceScale = viewModel.market.priceScale
        guard lastPrice != self.lastPrice || priceScale != self.priceScale else {
            return
        }
        self.lastPrice = lastPrice
        self.priceScale = priceScale
        if case let .candles(candles) = chart, !candles.isEmpty {
            configureChart(candles: candles, viewportState: chartView.viewportState)
        }
    }
    
    func setTimeFrame(frame: PerpetualTimeFrame) {
        guard let index = PerpetualTimeFrame.allCases.firstIndex(of: frame) else {
            return
        }
        setTimeFrameSelection(index: index, animated: false)
    }

    @objc private func changeTimeFrame(_ sender: UIButton) {
        setTimeFrameSelection(index: sender.tag, animated: true)
        let frame = PerpetualTimeFrame.allCases[sender.tag]
        delegate?.perpetualMarketPriceCell(self, didSelectTimeFrame: frame)
    }
    
    private func configureChart(
        candles: [PerpetualCandleViewModel],
        viewportState: CandleChartViewportState
    ) {
        let liveCandles = PerpetualCandleViewModel.withLivePrice(
            candles: candles,
            lastPrice: lastPrice,
            timeFrame: timeFrame
        )
        chartView.configure(
            candles: liveCandles,
            timeFrame: timeFrame,
            latestPrice: lastPrice,
            priceFormatMode: .decimal(priceScale: priceScale),
            viewportState: viewportState,
            animated: true
        )
    }
    
    private func setTimeFrameSelection(index: Int, animated: Bool) {
        for case let button as UIButton in timeFrameStackView.arrangedSubviews {
            button.isSelected = button.tag == index
        }
        for (i, divider) in timeFrameDividers.enumerated() {
            divider.isHidden = i == index || i + 1 == index
        }
        updateTimeFrameIndicator(index: index, animated: animated)
    }

    // The pill is pinned to the selected button with Auto Layout, so its first
    // placement and every relayout (rotation, width change) stay in sync with the buttons.
    private func updateTimeFrameIndicator(index: Int, animated: Bool) {
        let buttons = timeFrameStackView.arrangedSubviews.compactMap { $0 as? UIButton }
        guard let button = buttons.first(where: { $0.tag == index }) else {
            return
        }
        NSLayoutConstraint.deactivate(timeFrameIndicatorConstraints)
        timeFrameIndicatorConstraints = [
            timeFrameIndicatorView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            timeFrameIndicatorView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
        ]
        NSLayoutConstraint.activate(timeFrameIndicatorConstraints)
        timeFrameIndicatorView.isHidden = false
        if animated {
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0) {
                self.timeFrameScrollView.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation {
                self.timeFrameScrollView.layoutIfNeeded()
            }
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
