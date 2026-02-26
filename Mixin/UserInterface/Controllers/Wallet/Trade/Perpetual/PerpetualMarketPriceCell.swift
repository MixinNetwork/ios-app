import UIKit
import DGCharts
import MixinServices

final class PerpetualMarketPriceCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpetualMarketPriceCell(_ cell: PerpetualMarketPriceCell, didSelectTimeFrame timeFrame: PerpetualTimeFrame)
    }
    
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var chartView: CandleStickChartView!
    @IBOutlet weak var loadingIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var timeFrameStackView: UIStackView!
    
    weak var delegate: Delegate?
    
    private weak var unavailableView: UIView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        priceLabel.setFont(
            scaledFor: .systemFont(ofSize: 22, weight: .medium),
            adjustForContentSize: true
        )
        changeLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        for (i, timeFrame) in PerpetualTimeFrame.allCases.enumerated() {
            var config: UIButton.Configuration = .filled()
            let title = switch timeFrame {
            case .hour:
                "1H"
            case .day:
                R.string.localizable.days_count_short(1)
            case .week:
                R.string.localizable.weeks_count_short(1)
            case .month:
                R.string.localizable.months_count_short(1)
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
            timeFrameStackView.addArrangedSubview(button)
            button.addTarget(self, action: #selector(changeTimeFrame(_:)), for: .touchUpInside)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualMarketViewModel) {
        symbolLabel.text = viewModel.symbol
        priceLabel.text = viewModel.price
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
    }
    
    func load(chart: CandleChartData?) {
        if let chart {
            if let dataSet = chart.dataSets.first, dataSet.entryCount < 2 {
                showUnavailableView()
            } else {
                chartView.data = chart
                hideUnavailableView()
            }
            loadingIndicatorView.stopAnimating()
        } else {
            hideUnavailableView()
            loadingIndicatorView.startAnimating()
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
        hideUnavailableView()
        loadingIndicatorView.startAnimating()
        let frame = PerpetualTimeFrame.allCases[sender.tag]
        delegate?.perpetualMarketPriceCell(self, didSelectTimeFrame: frame)
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
