import UIKit
import MixinServices

final class TokenPriceChartCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func tokenPriceChartCell(_ cell: TokenPriceChartCell, didSelectPeriod period: PriceHistoryPeriod)
    }
    
    enum TokenAction: Int, CaseIterable {
        
        case swap
        case alert
        case addAlert
        
        var title: String {
            switch self {
            case .swap:
                R.string.localizable.swap()
            case .alert:
                R.string.localizable.alert()
            case .addAlert:
                R.string.localizable.add_alert()
            }
        }
        
    }
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var rankLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var chartView: ChartView!
    @IBOutlet weak var loadingIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var periodSelectorStackView: UIStackView!
    @IBOutlet weak var tokenActionView: PillActionView!
    
    @IBOutlet weak var periodSelectorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var periodSelectorScrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var tokenActionViewBottomConstraint: NSLayoutConstraint!
    
    weak var delegate: Delegate?
    
    var tokenActions: [TokenAction] = [] {
        didSet {
            if tokenActions.isEmpty {
                tokenActionView.isHidden = true
                periodSelectorScrollViewBottomConstraint.priority = .defaultHigh
                tokenActionViewBottomConstraint.priority = .defaultLow
            } else {
                tokenActionView.isHidden = false
                tokenActionView.actions = tokenActions.map { action in
                        .init(title: action.title)
                }
                periodSelectorScrollViewBottomConstraint.priority = .defaultLow
                tokenActionViewBottomConstraint.priority = .defaultHigh
            }
        }
    }
    
    private weak var unavailableView: UIView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleStackView.setCustomSpacing(9, after: titleLabel)
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        rankLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        rankLabel.layer.masksToBounds = true
        rankLabel.layer.cornerRadius = 4
        priceLabel.setFont(scaledFor: .systemFont(ofSize: 22, weight: .medium), adjustForContentSize: true)
        changeLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        chartView.annotateExtremums = true
        chartView.minPointPosition = 135 / 184
        chartView.maxPointPosition = 23 / 184
        for (i, period) in PriceHistoryPeriod.allCases.enumerated() {
            let button = UIButton(type: .system)
            button.tag = i
            let title = switch period {
            case .day:
                R.string.localizable.days_count_short(1)
            case .week:
                R.string.localizable.weeks_count_short(1)
            case .month:
                R.string.localizable.months_count_short(1)
            case .year:
                R.string.localizable.years_count_short(1)
            case .all:
                R.string.localizable.all()
            }
            button.setTitle(title, for: .normal)
            button.layer.cornerRadius = periodSelectorHeightConstraint.constant / 2
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            periodSelectorStackView.addArrangedSubview(button)
            button.addTarget(self, action: #selector(changePeriod(_:)), for: .touchUpInside)
        }
    }
    
    func setPeriodSelection(period: PriceHistoryPeriod) {
        guard let index = PriceHistoryPeriod.allCases.firstIndex(of: period) else {
            return
        }
        setPeriodSelection(index: index)
    }
    
    func updateChart(points: [ChartView.Point]?) {
        if let points {
            if points.count < 2 {
                showUnavailableView()
            } else {
                chartView.points = points
                hideUnavailableView()
            }
            loadingIndicatorView.stopAnimating()
        } else {
            hideUnavailableView()
            loadingIndicatorView.startAnimating()
        }
    }
    
    func updatePriceAndChangeByMarket(price: String?, points: [ChartView.Point]?) {
        priceLabel.text = price
        guard let points, points.count >= 2 else {
            changeLabel.alpha = 0
            return
        }
        let base = points[0]
        let now = points[points.count - 1]
        updateChange(base: base, now: now)
    }
    
    func updatePriceAndChangeByChart(base: ChartView.Point, now: ChartView.Point) {
        priceLabel.text = CurrencyFormatter.localizedString(
            from: now.value * Currency.current.decimalRate,
            format: .fiatMoneyPrice,
            sign: .never,
            symbol: .currencySymbol
        )
        updateChange(base: base, now: now)
    }
    
    @objc private func changePeriod(_ sender: UIButton) {
        setPeriodSelection(index: sender.tag)
        chartView.points = []
        hideUnavailableView()
        loadingIndicatorView.startAnimating()
        let period = PriceHistoryPeriod.allCases[sender.tag]
        delegate?.tokenPriceChartCell(self, didSelectPeriod: period)
    }
    
}

extension TokenPriceChartCell {
    
    private func showUnavailableView() {
        let unavailableView: UIView
        if let view = self.unavailableView {
            unavailableView = view
        } else {
            unavailableView = UnavailableView()
            contentView.addSubview(unavailableView)
            unavailableView.snp.makeConstraints { make in
                make.top.equalTo(titleStackView.snp.bottom).offset(24)
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-16)
                make.bottom.equalToSuperview().offset(-20)
            }
            self.unavailableView = unavailableView
        }
        unavailableView.isHidden = false
        periodSelectorStackView.isHidden = true
    }
    
    private func hideUnavailableView() {
        unavailableView?.isHidden = true
        periodSelectorStackView.isHidden = false
    }
    
    private func updateChange(base: ChartView.Point, now: ChartView.Point) {
        let change = (now.value - base.value) / base.value
        if let changePercentage = NumberFormatter.percentage.string(decimal: change) {
            changeLabel.text = changePercentage
            changeLabel.alpha = 1
        } else {
            changeLabel.alpha = 0
        }
        changeLabel.marketColor = .byValue(change)
    }
    
    private func setPeriodSelection(index: Int) {
        for case let button as UIButton in periodSelectorStackView.arrangedSubviews {
            if button.tag == index {
                button.backgroundColor = R.color.background_secondary()
                button.setTitleColor(R.color.text(), for: .normal)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(R.color.text_quaternary(), for: .normal)
            }
        }
    }
    
    private class UnavailableView: UIView {
        
        override class var layerClass: AnyClass {
            CAGradientLayer.self
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubview()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubview()
        }
        
        private func loadSubview() {
            let layer = self.layer as! CAGradientLayer
            layer.colors = [
                UIColor(displayP3RgbValue: 0xd9d9d9, alpha: 0.2).cgColor,
                UIColor(displayP3RgbValue: 0xd9d9d9, alpha: 0).cgColor,
            ]
            
            let label = UILabel()
            label.textColor = R.color.text_quaternary()
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = .preferredFont(forTextStyle: .caption1)
            label.adjustsFontForContentSizeCategory = true
            label.text = R.string.localizable.price_data_unavailable().uppercased()
            addSubview(label)
            label.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-16)
            }
        }
        
    }
    
}
