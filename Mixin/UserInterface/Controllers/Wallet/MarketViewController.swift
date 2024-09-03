import UIKit
import MixinServices

final class MarketViewController: UIViewController {
    
    private weak var tableView: UITableView!
    private weak var pushingViewController: UIViewController?
    
    private let id: String
    private let name: String
    
    private var market: Market?
    private var tokens: [TokenItem]?
    private var viewModel: MarketViewModel
    private var chartPeriod: PriceHistory.Period = .day
    private var chartPoints: [ChartView.Point]?
    
    private var tokenPriceChartCell: TokenPriceChartCell? {
        let indexPath = IndexPath(row: 0, section: Section.chart.rawValue)
        return tableView.cellForRow(at: indexPath) as? TokenPriceChartCell
    }
    
    private init(token: TokenItem, chartPoints: [ChartView.Point]?) {
        self.id = token.assetID
        self.name = token.name
        self.market = nil
        self.tokens = [token]
        self.viewModel = MarketViewModel(token: token)
        self.chartPoints = chartPoints
        super.init(nibName: nil, bundle: nil)
    }
    
    private init(market: Market) {
        self.id = market.coinID
        self.name = market.name
        self.market = market
        self.tokens = nil
        self.viewModel = MarketViewModel(market: market)
        self.chartPoints = nil
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
        let controller = MarketViewController(token: token, chartPoints: chartPoints)
        controller.pushingViewController = pushingViewController
        return ContainerViewController.instance(viewController: controller, title: token.symbol)
    }
    
    static func contained(
        market: Market,
        pushingViewController: UIViewController?
    ) -> ContainerViewController {
        let controller = MarketViewController(market: market)
        controller.pushingViewController = pushingViewController
        return ContainerViewController.instance(viewController: controller, title: market.symbol)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let container {
            container.setSubtitle(subtitle: name)
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
        
        DispatchQueue.global().async { [id, market, weak self] in
            if let market {
                if let ids = market.assetIDs, !ids.isEmpty {
                    let tokens = TokenDAO.shared.tokenItems(with: ids)
                    DispatchQueue.main.sync {
                        guard let self else {
                            return
                        }
                        self.tokens = tokens
                        self.viewModel.update(tokens: tokens)
                        self.viewModel.update(market: market)
                        self.tableView.reloadData()
                    }
                }
            } else {
                if let market = MarketDAO.shared.market(assetID: id) {
                    DispatchQueue.main.sync {
                        guard let self else {
                            return
                        }
                        self.market = market
                        self.viewModel.update(market: market)
                        self.tableView.reloadData()
                    }
                }
                RouteAPI.markets(id: id, queue: .global()) { result in
                    switch result {
                    case .success(let market):
                        MarketDAO.shared.save(market: market)
                        DispatchQueue.main.async {
                            guard let self else {
                                return
                            }
                            self.market = market
                            self.viewModel.update(market: market)
                            self.tableView.reloadData()
                        }
                    case .failure(.response(.notFound)):
                        DispatchQueue.main.async {
                            guard let self else {
                                return
                            }
                            self.market = nil
                            self.viewModel.updateWithMarketNotFound()
                            self.tableView.reloadData()
                        }
                    case .failure(let error):
                        Logger.general.debug(category: "MarketView", message: "\(error)")
                    }
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
    
    private func reloadPriceChart(period: PriceHistory.Period) {
        DispatchQueue.global().async { [id, weak self] in
            if let history = MarketDAO.shared.priceHistory(assetID: id, period: period),
               let points = TokenPrice(priceHistory: history)?.chartViewPoints()
            {
                DispatchQueue.main.sync {
                    self?.reloadPriceChart(period: period, points: points)
                }
            }
            RouteAPI.priceHistory(id: id, period: period, queue: .global()) { result in
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
                    Logger.general.debug(category: "MarketView", message: "\(error)")
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
            if let market {
                cell.updatePriceAndChange(price: market.localizedPrice, points: points)
            } else if let token = tokens?.first {
                cell.updatePriceAndChange(price: token.localizedFiatMoneyPrice, points: points)
            }
        }
    }
    
}

extension MarketViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .chart:
            1
        case .marketStats:
            viewModel.stats == nil ? 0 : MarketStatesRow.allCases.count
        case .myBalance:
            viewModel.balance == nil ? 0 : MyBalanceRow.allCases.count
        case .infos:
            viewModel.infos.count + 2 // 2 for separators
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .chart:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_price_chart, for: indexPath)!
            if let market {
                cell.tokenIconView.setIcon(market: market)
                cell.updatePriceAndChange(price: market.localizedPrice, points: chartPoints)
            } else if let token = tokens?.first {
                cell.tokenIconView.setIcon(token: token)
                cell.updatePriceAndChange(price: token.localizedFiatMoneyPrice, points: chartPoints)
            }
            cell.setPeriodSelection(period: chartPeriod)
            cell.updateChart(points: chartPoints)
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
            case .marketCap:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_stats, for: indexPath)!
                cell.leftTitleLabel.text = R.string.localizable.market_cap().uppercased()
                cell.setLeftContent(text: viewModel.stats?.marketCap)
                cell.rightTitleLabel.text = R.string.localizable.vol_24h(Currency.current.code).uppercased()
                
                cell.setRightContent(text: viewModel.stats?.fiatMoneyVolume24H)
                return cell
            case .price:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_stats, for: indexPath)!
                cell.leftTitleLabel.text = R.string.localizable.high_24h().uppercased()
                cell.setLeftContent(text: viewModel.stats?.high24H)
                cell.rightTitleLabel.text = R.string.localizable.low_24h().uppercased()
                cell.setRightContent(text: viewModel.stats?.low24H)
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
                if let balance = viewModel.balance {
                    cell.balanceLabel.text = balance.balance
                    cell.periodLabel.text = balance.period
                    cell.valueLabel.text = balance.value
                    cell.changeLabel.text = balance.change
                    cell.changeLabel.textColor = balance.changeColor
                }
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

extension MarketViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .chart:
            return UITableView.automaticDimension
        case .marketStats:
            return switch MarketStatesRow(rawValue: indexPath.row)! {
            case .title, .price, .marketCap:
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
        switch Section(rawValue: section)! {
        case .chart:
            10
        case .marketStats:
            viewModel.stats == nil ? .leastNormalMagnitude : 10
        case .myBalance:
            viewModel.balance == nil ? .leastNormalMagnitude : 10
        case .infos:
            10
        }
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
            if pushingViewController is TokenViewController {
                navigationController?.popViewController(animated: true)
            } else if let tokens {
                if tokens.count == 1 {
                    let controller = TokenViewController.contained(token: tokens[0])
                    navigationController?.pushViewController(controller, animated: true)
                } else if tokens.count > 1 {
                    let selector = MarketTokenSelectorViewController(name: name, tokens: tokens) { index in
                        let token = tokens[index]
                        let controller = TokenViewController.contained(token: token)
                        self.navigationController?.pushViewController(controller, animated: true)
                    }
                    present(selector, animated: true)
                }
            }
        default:
            break
        }
    }
    
}

extension MarketViewController: ChartView.Delegate {
    
    func chartView(_ view: ChartView, extremumAnnotationForPoint point: ChartView.Point) -> String {
        CurrencyFormatter.localizedString(
            from: point.value * Currency.current.decimalRate,
            format: .fiatMoneyPrice,
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
        guard let cell = tokenPriceChartCell else {
            return
        }
        if let market {
            cell.tokenIconView.setIcon(market: market)
            cell.updatePriceAndChange(price: market.localizedPrice, points: chartPoints)
        } else if let token = tokens?.first {
            cell.tokenIconView.setIcon(token: token)
            cell.updatePriceAndChange(price: token.localizedFiatMoneyPrice, points: chartPoints)
        }
    }
    
}

extension MarketViewController: TokenPriceChartCell.Delegate {
    
    func tokenPriceChartCell(_ cell: TokenPriceChartCell, didSelectPeriod period: PriceHistory.Period) {
        chartPoints = nil
        self.chartPeriod = period
        reloadPriceChart(period: period)
    }
    
}

extension MarketViewController {
    
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
        case marketCap
        case price
        case bottomSeparator
    }
    
    private class MarketViewModel {
        
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
            
            static func tokenInfos(token: TokenItem) -> [Info] {
                var infos = [
                    Info(
                        title: R.string.localizable.contract_address().uppercased(),
                        primaryContent: token.assetKey,
                        secondaryContent: (R.string.localizable.address_warning(), R.color.red()!)
                    )
                ]
                if let chainName = token.chain?.name {
                    let info = Info(title: R.string.localizable.chain().uppercased(), primaryContent: chainName)
                    infos.insert(info, at: 0)
                }
                return infos
            }
            
            static func marketInfos(market: Market) -> [Info] {
                var infos: [Info] = []
                if let marketCap = Decimal(string: market.marketCap, locale: .enUSPOSIX) {
                    let title = R.string.localizable.market_cap().uppercased()
                    switch marketCap {
                    case 0:
                        infos.append(Info.contentNotApplicable(title: title))
                    default:
                        let value = marketCap * Currency.current.decimalRate
                        if let content = NamedLargeNumberFormatter.string(number: value, currencyPrefix: true) {
                            infos.append(Info(title: title, primaryContent: content))
                        }
                    }
                }
                if let circulatingSupply = Decimal(string: market.circulatingSupply, locale: .enUSPOSIX) {
                    let title = R.string.localizable.circulation_supply().uppercased()
                    switch circulatingSupply {
                    case 0:
                        infos.append(Info.contentNotApplicable(title: title))
                    default:
                        if let content = NamedLargeNumberFormatter.string(number: circulatingSupply, currencyPrefix: false) {
                            infos.append(Info(title: title, primaryContent: content + " " + market.symbol))
                        }
                    }
                }
                if let totalSupply = Decimal(string: market.totalSupply, locale: .enUSPOSIX) {
                    let title = R.string.localizable.total_supply().uppercased()
                    switch totalSupply {
                    case 0:
                        infos.append(Info.contentNotApplicable(title: title))
                    default:
                        if let content = NamedLargeNumberFormatter.string(number: totalSupply, currencyPrefix: false) {
                            infos.append(Info(title: title, primaryContent: content + " " + market.symbol))
                        }
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
                return infos
            }
            
        }
        
        struct Stats {
            let high24H: String?
            let low24H: String?
            let marketCap: String?
            let fiatMoneyVolume24H: String?
        }
        
        struct Balance {
            
            let balance: String
            let period: String
            let value: String
            let change: String
            let changeColor: UIColor
            
            init(balance: String, period: String, value: String, change: String, changeColor: UIColor) {
                self.balance = balance
                self.period = period
                self.value = value
                self.change = change
                self.changeColor = changeColor
            }
            
            init(token: TokenItem) {
                self.init(
                    balance: token.localizedBalanceWithSymbol,
                    period: R.string.localizable.hours_count_short(24),
                    value: token.localizedFiatMoneyBalance,
                    change: "",
                    changeColor: .clear
                )
            }
            
            func replacing(change: String, changeColor: UIColor) -> Balance {
                Balance(
                    balance: self.balance,
                    period: self.period,
                    value: self.value,
                    change: change,
                    changeColor: changeColor
                )
            }
            
        }
        
        private(set) var market: Market?
        private(set) var token: TokenItem?
        private(set) var stats: Stats?
        private(set) var balance: Balance?
        private(set) var infos: [Info]
        
        private let symbol: String
        private let basicInfos: [Info]
        
        private var tokenInfos: [Info]
        private var marketInfos: [Info]
        
        init(market: Market) {
            self.market = market
            self.token = nil
            self.stats = nil
            self.balance = nil
            self.symbol = market.symbol
            self.basicInfos = [
                Info(title: R.string.localizable.name().uppercased(), primaryContent: market.name),
                Info(title: R.string.localizable.symbol().uppercased(), primaryContent: market.symbol),
            ]
            self.tokenInfos = []
            self.marketInfos = Info.marketInfos(market: market)
            self.infos = basicInfos + tokenInfos + marketInfos
        }
        
        init(token: TokenItem) {
            self.market = nil
            self.token = token
            self.stats = nil
            self.balance = Balance(token: token)
            self.symbol = token.symbol
            self.basicInfos = [
                Info(title: R.string.localizable.name().uppercased(), primaryContent: token.name),
                Info(title: R.string.localizable.symbol().uppercased(), primaryContent: token.symbol),
            ]
            self.tokenInfos = Info.tokenInfos(token: token)
            self.marketInfos = []
            self.infos = basicInfos + tokenInfos
        }
        
        func updateWithMarketNotFound() {
            self.stats = nil
            if let balance {
                self.balance = balance.replacing(change: notApplicable, changeColor: R.color.text_quaternary()!)
            }
            self.marketInfos = [
                Info.contentNotApplicable(title: R.string.localizable.market_cap().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.circulation_supply().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.total_supply().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.all_time_high().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.all_time_low().uppercased()),
            ]
            self.infos = basicInfos + tokenInfos + marketInfos
        }
        
        func update(tokens: [TokenItem]) {
            if tokens.count == 1 {
                let token = tokens[0]
                self.token = token
                self.balance = Balance(token: token)
                self.tokenInfos = Info.tokenInfos(token: token)
                self.infos = basicInfos + tokenInfos + marketInfos
            } else if tokens.count > 1, let market {
                let balanceSum: Decimal = tokens.reduce(0) { result, item in
                    result + item.decimalBalance
                }
                let balanceSumString = CurrencyFormatter.localizedString(
                    from: balanceSum,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(symbol)
                )
                let valueString = "≈ " + CurrencyFormatter.localizedString(
                    from: balanceSum * market.decimalPrice * Currency.current.decimalRate,
                    format: .fiatMoney,
                    sign: .never,
                    symbol: .currencySymbol
                )
                self.balance = Balance(
                    balance: balanceSumString,
                    period: R.string.localizable.hours_count_short(24),
                    value: valueString,
                    change: "",
                    changeColor: .clear
                )
            }
        }
        
        func update(market: Market) {
            self.market = market
            self.stats = {
                let high24H: String?
                if let value = Decimal(string: market.high24H, locale: .enUSPOSIX) {
                    high24H = CurrencyFormatter.localizedString(
                        from: value * Currency.current.decimalRate,
                        format: .fiatMoneyPrice,
                        sign: .never,
                        symbol: .currencySymbol
                    )
                } else {
                    high24H = nil
                }
                let low24H: String?
                if let value = Decimal(string: market.low24H, locale: .enUSPOSIX) {
                    low24H = CurrencyFormatter.localizedString(
                        from: value * Currency.current.decimalRate,
                        format: .fiatMoneyPrice,
                        sign: .never,
                        symbol: .currencySymbol
                    )
                } else {
                    low24H = nil
                }
                let marketCap: String?
                if let value = Decimal(string: market.marketCap, locale: .enUSPOSIX) {
                    marketCap = NamedLargeNumberFormatter.string(number: value, currencyPrefix: true)
                } else {
                    marketCap = nil
                }
                let fiatMoneyVolume24H: String?
                if let totalVolume = Decimal(string: market.totalVolume, locale: .enUSPOSIX) {
                    fiatMoneyVolume24H = NamedLargeNumberFormatter.string(
                        number: totalVolume * Currency.current.decimalRate,
                        currencyPrefix: false
                    )
                } else {
                    fiatMoneyVolume24H = nil
                }
                return Stats(
                    high24H: high24H,
                    low24H: low24H,
                    marketCap: marketCap,
                    fiatMoneyVolume24H: fiatMoneyVolume24H
                )
            }()
            if let priceChange24H = Decimal(string: market.priceChange24H, locale: .enUSPOSIX), let token {
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
                if let balance {
                    let color: UIColor = priceChange24H >= 0 ? .priceRising : .priceFalling
                    self.balance = balance.replacing(change: change, changeColor: color)
                }
            }
            self.marketInfos = Info.marketInfos(market: market)
            self.infos = basicInfos + tokenInfos + marketInfos
        }
        
    }
    
}
