import UIKit
import MixinServices

final class TokenMarketViewController: UIViewController {
    
    private let token: TokenItem
    
    private weak var tableView: UITableView!
    private weak var pushingViewController: UIViewController?
    
    private var viewModel: MarketViewModel
    private var chartPeriod: PriceHistory.Period = .day
    private var chartPoints: [ChartView.Point]?
    
    private var tokenPriceChartCell: TokenPriceChartCell? {
        let indexPath = IndexPath(row: 0, section: Section.chart.rawValue)
        return tableView.cellForRow(at: indexPath) as? TokenPriceChartCell
    }
    
    private init(token: TokenItem, chartPoints: [ChartView.Point]?) {
        self.token = token
        self.viewModel = MarketViewModel(token: token)
        self.chartPoints = chartPoints
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    static func contained(
        token: TokenItem,
        chartPoints: [ChartView.Point]?,
        pushingViewController: UIViewController?
    ) -> ContainerViewController {
        let controller = TokenMarketViewController(token: token, chartPoints: chartPoints)
        controller.pushingViewController = pushingViewController
        return ContainerViewController.instance(viewController: controller, title: token.name)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let container {
            container.setSubtitle(subtitle: token.depositNetworkName)
            container.view.backgroundColor = R.color.background_secondary()
            container.navigationBar.backgroundColor = R.color.background_secondary()
        }
        
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 110
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.register(R.nib.tokenPriceChartCell)
        tableView.register(R.nib.insetGroupedTitleCell)
        tableView.register(R.nib.tokenStatsCell)
        tableView.register(R.nib.tokenMyBalanceCell)
        tableView.register(R.nib.tokenInfoCell)
        tableView.register(UITableViewCell.self,
                           forCellReuseIdentifier: ReuseIdentifier.emptyCell)
        tableView.register(UITableViewHeaderFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseIdentifier.header)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        
        var viewModel = self.viewModel
        DispatchQueue.global().async { [id=token.assetID, weak self] in
            if let market = MarketDAO.shared.market(assetID: id) {
                viewModel.update(with: market)
                DispatchQueue.main.sync {
                    self?.reloadData(viewModel: viewModel)
                }
            }
            RouteAPI.market(assetID: id) { result in
                switch result {
                case .success(let tm):
                    let market = tm.asMarket()
                    MarketDAO.shared.saveMarket(market)
                    viewModel.update(with: market)
                    DispatchQueue.main.async {
                        self?.reloadData(viewModel: viewModel)
                    }
                case .failure(.response(.notFound)):
                    viewModel.updateWithNotFound()
                    DispatchQueue.main.async {
                        self?.reloadData(viewModel: viewModel)
                    }
                case .failure(let error):
                    Logger.general.debug(category: "TokenMarketView", message: "\(error)")
                }
            }
        }
        if chartPoints == nil {
            reloadPriceChart(period: chartPeriod)
        }
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    private func reloadData(viewModel: MarketViewModel) {
        self.viewModel = viewModel
        tableView.reloadData()
    }
    
    private func reloadPriceChart(period: PriceHistory.Period) {
        DispatchQueue.global().async { [id=token.assetID, weak self] in
            if let history = MarketDAO.shared.priceHistory(assetID: id, period: period),
               let points = TokenPrice(priceHistory: history)?.chartViewPoints()
            {
                DispatchQueue.main.sync {
                    self?.reloadPriceChart(period: period, points: points)
                }
            }
            RouteAPI.priceHistory(assetID: id, period: period, queue: .global()) { result in
                switch result {
                case .success(let price):
                    if let history = price.asPriceHistory() {
                        MarketDAO.shared.savePriceHistory(history)
                    }
                    let points = price.chartViewPoints()
                    DispatchQueue.main.async {
                        self?.reloadPriceChart(period: period, points: points)
                    }
                case .failure(let error):
                    Logger.general.debug(category: "TokenMarketView", message: "\(error)")
                }
            }
        }
    }
    
    private func reloadPriceChart(period: PriceHistory.Period, points: [ChartView.Point]) {
        guard period == self.chartPeriod else {
            return
        }
        self.chartPoints = points
        if let cell = tokenPriceChartCell {
            cell.updateChart(points: points)
            cell.updatePriceAndChange(token: token, points: points)
        }
    }
    
}

extension TokenMarketViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .chart:
            1
        case .marketStats:
            MarketStatesRow.allCases.count
        case .myBalance:
            MyBalanceRow.allCases.count
        case .infos:
            viewModel.infos.count + 2 // 2 for separators
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .chart:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_price_chart, for: indexPath)!
            cell.tokenIconView.setIcon(token: token)
            cell.setPeriodSelection(period: chartPeriod)
            cell.updateChart(points: chartPoints)
            cell.updatePriceAndChange(token: token, points: chartPoints)
            cell.delegate = self
            cell.chartView.delegate = self
            return cell
        case .marketStats:
            switch MarketStatesRow(rawValue: indexPath.row)! {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.stats()
                cell.disclosureIndicatorView.isHidden = true
                return cell
            case .price:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_stats, for: indexPath)!
                cell.leftTitleLabel.text = R.string.localizable.high_24h().uppercased()
                cell.setLeftContent(text: viewModel.high24H)
                cell.rightTitleLabel.text = R.string.localizable.low_24h().uppercased()
                cell.setRightContent(text: viewModel.low24H)
                return cell
            case .volume:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_stats, for: indexPath)!
                cell.leftTitleLabel.text = R.string.localizable.vol_24h(Currency.current.code)
                cell.setLeftContent(text: viewModel.fiatMoneyVolume24H)
                cell.rightTitleLabel.text = nil
                cell.rightContentLabel.text = nil
                return cell
            case .bottomSeparator:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.emptyCell, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            }
        case .myBalance:
            switch MyBalanceRow(rawValue: indexPath.row)! {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.my_balance()
                cell.disclosureIndicatorView.isHidden = false
                return cell
            case .content:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_my_balance, for: indexPath)!
                cell.balanceLabel.text = token.localizedBalanceWithSymbol
                cell.periodLabel.text = R.string.localizable.hours_count_short(24)
                cell.valueLabel.text = token.localizedFiatMoneyBalance
                cell.changeLabel.text = viewModel.priceChange
                cell.changeLabel.textColor = viewModel.priceChangeColor
                return cell
            }
        case .infos:
            let index = indexPath.row - 1
            if index >= 0 && index < viewModel.infos.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_info, for: indexPath)!
                let row = viewModel.infos[index]
                cell.titleLabel.text = row.title
                cell.primaryContentLabel.text = row.primaryContent
                cell.primaryContentLabel.textColor = row.primaryContentColor
                if let content = row.secondaryContent {
                    (cell.secondaryContentLabel.text, cell.secondaryContentLabel.textColor) = content
                    cell.secondaryContentLabel.isHidden = false
                } else {
                    cell.secondaryContentLabel.isHidden = true
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.emptyCell, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            }
        }
    }
    
}

extension TokenMarketViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .chart:
            return UITableView.automaticDimension
        case .marketStats:
            return switch MarketStatesRow(rawValue: indexPath.row)! {
            case .title, .price, .volume:
                UITableView.automaticDimension
            case .bottomSeparator:
                10
            }
        case .myBalance:
            return UITableView.automaticDimension
        case .infos:
            let index = indexPath.row - 1
            return if index >= 0 && index < viewModel.infos.count {
                UITableView.automaticDimension
            } else {
                10
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        10
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseIdentifier.header)!
        view.contentView.backgroundColor = R.color.background_secondary()
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .myBalance:
            switch MyBalanceRow(rawValue: indexPath.row)! {
            case .title:
                if pushingViewController is TokenViewController {
                    navigationController?.popViewController(animated: true)
                }
            default:
                break
            }
        default:
            break
        }
    }
    
}

extension TokenMarketViewController: ChartView.Delegate {
    
    func chartView(_ view: ChartView, extremumAnnotationForPoint point: ChartView.Point) -> String {
        CurrencyFormatter.localizedString(
            from: point.value * Currency.current.decimalRate,
            format: .fiatMoney,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    func chartView(_ view: ChartView, inspectionAnnotationForPoint point: ChartView.Point) -> String {
        switch chartPeriod {
        case .day:
            DateFormatter.shortTimeOnly.string(from: point.date)
        case .week, .month, .ytd, .all:
            DateFormatter.shortDateOnly.string(from: point.date)
        }
    }
    
    func chartView(_ view: ChartView, didSelectPoint point: ChartView.Point) {
        guard let base = view.points.first else {
            return
        }
        tokenPriceChartCell?.updatePriceAndChange(base: base, now: point)
    }
    
    func chartViewDidCancelSelection(_ view: ChartView) {
        tokenPriceChartCell?.updatePriceAndChange(token: token, points: view.points)
    }
    
}

extension TokenMarketViewController: TokenPriceChartCell.Delegate {
    
    func tokenPriceChartCell(_ cell: TokenPriceChartCell, didSelectPeriod period: PriceHistory.Period) {
        chartPoints = nil
        self.chartPeriod = period
        reloadPriceChart(period: period)
    }
    
}

extension TokenMarketViewController {
    
    private enum ReuseIdentifier {
        static let header = "header"
        static let emptyCell = "emtpy_cell"
    }
    
    private enum Section: Int, CaseIterable {
        case chart
        case marketStats
        case myBalance
        case infos
    }
    
    private enum MyBalanceRow: Int, CaseIterable {
        case title
        case content
    }
    
    private enum MarketStatesRow: Int, CaseIterable {
        case title
        case price
        case volume
        case bottomSeparator
    }
    
    private struct MarketViewModel {
        
        struct Info {
            
            let title: String
            let primaryContent: String
            let primaryContentColor: UIColor
            let secondaryContent: (String, UIColor)?
            
            init(
                title: String,
                primaryContent: String,
                primaryContentColor: UIColor = R.color.text()!,
                secondaryContent: (String, UIColor)? = nil
            ) {
                self.title = title
                self.primaryContent = primaryContent
                self.primaryContentColor = primaryContentColor
                self.secondaryContent = secondaryContent
            }
            
            static func contentNotApplicable(title: String) -> Info {
                Info(
                    title: title,
                    primaryContent: notApplicable,
                    primaryContentColor: R.color.text_tertiary()!
                )
            }
            
        }
        
        private let token: TokenItem
        private let fixedInfosCount: Int
        
        private(set) var high24H: String?
        private(set) var low24H: String?
        private(set) var fiatMoneyVolume24H: String?
        private(set) var priceChange: String
        private(set) var priceChangeColor: UIColor
        private(set) var infos: [Info]
        
        init(token: TokenItem) {
            var infos = [
                Info(title: R.string.localizable.name().uppercased(), primaryContent: token.name),
                Info(title: R.string.localizable.symbol().uppercased(), primaryContent: token.symbol),
            ]
            if let chainName = token.chain?.name {
                infos.append(Info(title: R.string.localizable.chain().uppercased(), primaryContent: chainName))
            }
            infos.append(
                Info(
                    title: R.string.localizable.contract_address().uppercased(),
                    primaryContent: token.assetKey,
                    secondaryContent: (R.string.localizable.address_warning(), R.color.red()!)
                )
            )
            
            self.token = token
            self.fixedInfosCount = infos.count
            self.high24H = nil
            self.low24H = nil
            self.fiatMoneyVolume24H = nil
            self.priceChange = ""
            self.priceChangeColor = .clear
            self.infos = infos
        }
        
        mutating func updateWithNotFound() {
            var infos = Array(self.infos.prefix(fixedInfosCount))
            infos.append(contentsOf: [
                Info.contentNotApplicable(title: R.string.localizable.market_cap().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.circulation_supply().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.total_supply().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.all_time_high().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.all_time_low().uppercased()),
            ])
            
            self.high24H = nil
            self.low24H = nil
            self.fiatMoneyVolume24H = nil
            self.priceChange = notApplicable
            self.priceChangeColor = R.color.text_quaternary()!
            self.infos = infos
        }
        
        mutating func update(with market: Market) {
            if let high24H = Decimal(string: market.high24H, locale: .enUSPOSIX) {
                self.high24H = CurrencyFormatter.localizedString(
                    from: high24H * Currency.current.decimalRate,
                    format: .fiatMoneyPrice,
                    sign: .never,
                    symbol: .currencySymbol
                )
            }
            if let low24H = Decimal(string: market.low24H, locale: .enUSPOSIX) {
                self.low24H = CurrencyFormatter.localizedString(
                    from: low24H * Currency.current.decimalRate,
                    format: .fiatMoneyPrice,
                    sign: .never,
                    symbol: .currencySymbol
                )
            }
            if let totalVolume = Decimal(string: market.totalVolume, locale: .enUSPOSIX) {
                self.fiatMoneyVolume24H = CurrencyFormatter.localizedString(
                    from: totalVolume * Currency.current.decimalRate,
                    format: .fiatMoney,
                    sign: .never
                )
            }
            if let priceChange24H = Decimal(string: market.priceChange24H, locale: .enUSPOSIX) {
                var change = CurrencyFormatter.localizedString(
                    from: priceChange24H * token.decimalBalance * Currency.current.decimalRate,
                    format: .fiatMoneyPrice,
                    sign: .always,
                    symbol: .currencySymbol
                )
                if let priceChangePercentage24H = Decimal(string: market.priceChangePercentage24H, locale: .enUSPOSIX),
                   let percent = NumberFormatter.percentage.string(decimal: priceChangePercentage24H / 100)
                {
                    change += " (\(percent))"
                }
                self.priceChange = change
                self.priceChangeColor = priceChange24H >= 0 ? .priceRising : .priceFalling
            }
            
            var infos = Array(self.infos.prefix(fixedInfosCount))
            if let marketCap = Decimal(string: market.marketCap, locale: .enUSPOSIX) {
                let title = R.string.localizable.market_cap().uppercased()
                switch marketCap {
                case 0:
                    infos.append(Info.contentNotApplicable(title: title))
                default:
                    let content = CurrencyFormatter.localizedString(
                        from: marketCap * Currency.current.decimalRate,
                        format: .fiatMoney,
                        sign: .never,
                        symbol: .currencySymbol
                    )
                    infos.append(Info(title: title, primaryContent: content))
                }
            }
            if let circulatingSupply = Decimal(string: market.circulatingSupply, locale: .enUSPOSIX) {
                let title = R.string.localizable.circulation_supply().uppercased()
                switch circulatingSupply {
                case 0:
                    infos.append(Info.contentNotApplicable(title: title))
                default:
                    let content = CurrencyFormatter.localizedString(
                        from: circulatingSupply,
                        format: .precision,
                        sign: .never,
                        symbol: .custom(token.symbol)
                    )
                    infos.append(Info(title: title, primaryContent: content))
                }
            }
            if let totalSupply = Decimal(string: market.totalSupply, locale: .enUSPOSIX) {
                let title = R.string.localizable.total_supply().uppercased()
                switch totalSupply {
                case 0:
                    infos.append(Info.contentNotApplicable(title: title))
                default:
                    let content = CurrencyFormatter.localizedString(
                        from: totalSupply,
                        format: .precision,
                        sign: .never,
                        symbol: .custom(token.symbol)
                    )
                    infos.append(Info(title: title, primaryContent: content))
                }
            }
            
            if let ath = Decimal(string: market.ath, locale: .enUSPOSIX) {
                let title = R.string.localizable.all_time_high().uppercased()
                switch ath {
                case 0:
                    infos.append(Info.contentNotApplicable(title: title))
                default:
                    let price = CurrencyFormatter.localizedString(
                        from: ath * Currency.current.decimalRate,
                        format: .fiatMoneyPrice,
                        sign: .never,
                        symbol: .currencySymbol
                    )
                    let date = (
                        DateFormatter.shortDateOnly.string(from: market.athDate.toUTCDate()),
                        R.color.text_tertiary()!
                    )
                    infos.append(Info(title: title, primaryContent: price, secondaryContent: date))
                }
            }
            if let atl = Decimal(string: market.atl, locale: .enUSPOSIX) {
                let title = R.string.localizable.all_time_low().uppercased()
                switch atl {
                case 0:
                    infos.append(Info.contentNotApplicable(title: title))
                default:
                    let price = CurrencyFormatter.localizedString(
                        from: atl * Currency.current.decimalRate,
                        format: .fiatMoneyPrice,
                        sign: .never,
                        symbol: .currencySymbol
                    )
                    let date = (
                        DateFormatter.shortDateOnly.string(from: market.atlDate.toUTCDate()),
                        R.color.text_tertiary()!
                    )
                    infos.append(Info(title: title, primaryContent: price, secondaryContent: date))
                }
            }
            self.infos = infos
        }
        
    }
    
}