import UIKit
import MixinServices

final class ShareMarketContentView: UIView {
    
    @IBOutlet weak var chartSectionView: UIView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var rankLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var tokenIconView: PlainTokenIconView!
    @IBOutlet weak var chartView: ChartView!
    @IBOutlet weak var periodSelectorStackView: UIStackView!
    @IBOutlet weak var marketCapTitleLabel: UILabel!
    @IBOutlet weak var marketCapContentLabel: UILabel!
    @IBOutlet weak var volumeTitleLabel: UILabel!
    @IBOutlet weak var volumeContentLabel: UILabel!
    @IBOutlet weak var highTitleLabel: UILabel!
    @IBOutlet weak var highContentLabel: UILabel!
    @IBOutlet weak var lowTitleLabel: UILabel!
    @IBOutlet weak var lowContentLabel: UILabel!
    @IBOutlet weak var periodSelectorHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var statisticsSectionView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statisticsStackView: UIStackView!
    
    @IBOutlet weak var obiView: ShareObiView!
    
    private weak var unavailableView: UIView?
    
    private var sectionViews: [UIView] {
        [chartSectionView, statisticsSectionView]
    }
    
    private var statsTitleLabels: [UILabel] {
        [
            marketCapTitleLabel,
            volumeTitleLabel,
            highTitleLabel,
            lowTitleLabel,
        ]
    }
    
    private var statsContentLabels: [UILabel] {
        [
            marketCapContentLabel,
            volumeContentLabel,
            highContentLabel,
            lowContentLabel,
        ]
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        for sectionView in sectionViews {
            sectionView.layer.cornerRadius = 8
            sectionView.layer.masksToBounds = true
        }
        titleStackView.setCustomSpacing(9, after: titleLabel)
        titleLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
        rankLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        rankLabel.layer.masksToBounds = true
        rankLabel.layer.cornerRadius = 4
        rankLabel.font = .systemFont(
            ofSize: 12,
            weight: .accessiblityBoldTextCounterWeight(.medium)
        )
        priceLabel.font = .systemFont(
            ofSize: 22,
            weight: .accessiblityBoldTextCounterWeight(.medium)
        )
        changeLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
        chartView.annotateExtremums = true
        chartView.minPointPosition = 135 / 184
        chartView.maxPointPosition = 23 / 184
        chartView.delegate = self
        for (i, period) in PriceHistoryPeriod.allCases.enumerated() {
            let label = InsetLabel()
            label.tag = i
            label.font = .systemFont(
                ofSize: 14,
                weight: .accessiblityBoldTextCounterWeight(.regular)
            )
            label.textAlignment = .center
            label.text = switch period {
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
            label.layer.cornerRadius = periodSelectorHeightConstraint.constant / 2
            label.layer.masksToBounds = true
            label.contentInset = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            periodSelectorStackView.addArrangedSubview(label)
        }
        
        nameLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
        for label in statsTitleLabels {
            label.font = .systemFont(
                ofSize: 12,
                weight: .accessiblityBoldTextCounterWeight(.regular)
            )
        }
        marketCapTitleLabel.text = R.string.localizable.market_cap().uppercased()
        volumeTitleLabel.text = R.string.localizable.volume_24h().uppercased()
        highTitleLabel.text = R.string.localizable.high_24h().uppercased()
        lowTitleLabel.text = R.string.localizable.low_24h().uppercased()
        for label in statsContentLabels {
            label.font = .systemFont(
                ofSize: 14,
                weight: .accessiblityBoldTextCounterWeight(.regular)
            )
        }
        obiView.load(content: .installMixin(gradient: true))
    }
    
    func showUnavailableView() {
        let unavailableView: UIView
        if let view = self.unavailableView {
            unavailableView = view
        } else {
            unavailableView = PriceDataUnavailableView()
            addSubview(unavailableView)
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
    
    func hideUnavailableView() {
        unavailableView?.isHidden = true
        periodSelectorStackView.isHidden = false
    }
    
    func setPeriodSelection(index: Int) {
        for case let label as UILabel in periodSelectorStackView.arrangedSubviews {
            if label.tag == index {
                label.backgroundColor = R.color.background_secondary()
                label.textColor = R.color.text()
            } else {
                label.backgroundColor = .clear
                label.textColor = R.color.text_quaternary()
            }
        }
    }
    
}

extension ShareMarketContentView: ChartView.Delegate {
    
    func chartView(_ view: ChartView, extremumAnnotationForPoint point: ChartView.Point) -> String {
        CurrencyFormatter.localizedString(
            from: point.value * Currency.current.decimalRate,
            format: .fiatMoneyPrice,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    func chartView(_ view: ChartView, inspectionAnnotationForPoint point: ChartView.Point) -> String {
        ""
    }
    
    func chartView(_ view: ChartView, didSelectPoint point: ChartView.Point) {
        
    }
    
    func chartViewDidCancelSelection(_ view: ChartView) {
        
    }
    
}
