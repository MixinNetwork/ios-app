import UIKit
import MixinServices

final class MarketViewController: UIViewController {
    
    weak var pushingViewController: UIViewController?
    
    private weak var tableView: UITableView!
    private weak var favoriteBarButtonItem: UIBarButtonItem!
    
    private let id: Identifier
    private let isMalicious: Bool
    private let maliciousWarningReuseIdentifier = "m"
    
    private var market: FavorableMarket?
    private var tokens: [MixinTokenItem]?
    private var viewModel: MarketViewModel
    private var chartPeriod: PriceHistoryPeriod = .day
    private var chartPoints: [ChartView.Point]?
    private var hasAlert = true
    private var requester: MarketPeriodicRequester!
    
    private var tokenPriceChartCell: TokenPriceChartCell? {
        let indexPath = IndexPath(row: 0, section: Section.chart.rawValue)
        return tableView.cellForRow(at: indexPath) as? TokenPriceChartCell
    }
    
    init(token: MixinTokenItem, chartPoints: [ChartView.Point]?) {
        self.id = .asset(token.assetID)
        self.isMalicious = token.isMalicious
        self.market = nil
        self.tokens = [token]
        self.viewModel = MarketViewModel(token: token)
        self.chartPoints = chartPoints
        super.init(nibName: nil, bundle: nil)
        self.title = token.symbol
    }
    
    init(token: Web3Token, chartPoints: [ChartView.Point]?) {
        self.id = .asset(token.assetID)
        self.isMalicious = token.isMalicious
        self.market = nil
        self.tokens = nil
        self.viewModel = MarketViewModel(token: token)
        self.chartPoints = chartPoints
        super.init(nibName: nil, bundle: nil)
        self.title = token.symbol
    }
    
    init(market: FavorableMarket) {
        self.id = .coin(market.coinID)
        self.isMalicious = false
        self.market = market
        self.tokens = nil
        self.viewModel = MarketViewModel(market: market)
        self.chartPoints = nil
        super.init(nibName: nil, bundle: nil)
        self.title = market.symbol
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let favoriteBarButtonItem: UIBarButtonItem = .tintedIcon(
            image: nil,
            target: self,
            action: #selector(toggleFavorite(_:))
        )
        navigationItem.rightBarButtonItems = [
            .tintedIcon(image: R.image.ic_share(), target: self, action: #selector(shareMarket(_:))),
            favoriteBarButtonItem,
        ]
        self.favoriteBarButtonItem = favoriteBarButtonItem
        
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 110
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.register(
            MaliciousTokenWarningCell.self,
            forCellReuseIdentifier: maliciousWarningReuseIdentifier
        )
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
        
        if chartPoints == nil {
            reloadPriceChart(period: chartPeriod)
        }
        
        if let market {
            viewModel.update(market: market, tokens: [])
            tableView.reloadData()
            updateFavoriteButtonImage()
        }
        reloadFromLocal()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFromLocal),
            name: MarketDAO.didUpdateNotification,
            object: nil
        )
        requester = MarketPeriodicRequester(id: id.value, onNotFound: { [weak self] in
            guard let self else {
                return
            }
            self.market = nil
            self.viewModel.updateWithMarketNotFound()
            self.tableView.reloadData()
            self.updateFavoriteButtonImage()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ConcurrentJobQueue.shared.addJob(job: ReloadGlobalMarketJob())
        requester.start()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        requester.pause()
    }
    
    @objc private func toggleFavorite(_ sender: Any) {
        guard let market else {
            return
        }
        if market.isFavorite {
            market.isFavorite = false
            updateFavoriteButtonImage()
            RouteAPI.unfavoriteMarket(coinID: market.coinID) { [weak self] result in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        MarketDAO.shared.unfavorite(coinID: market.coinID, sendNotification: true)
                    }
                case .failure(let error):
                    if let self {
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                        market.isFavorite = true
                        self.updateFavoriteButtonImage()
                    }
                }
            }
        } else {
            market.isFavorite = true
            updateFavoriteButtonImage()
            RouteAPI.favoriteMarket(coinID: market.coinID) { [weak self] result in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        MarketDAO.shared.favorite(coinID: market.coinID, sendNotification: true)
                    }
                case .failure(let error):
                    if let self {
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                        market.isFavorite = false
                        self.updateFavoriteButtonImage()
                    }
                }
            }
        }
    }
    
    @objc private func shareMarket(_ sender: Any) {
        guard let market else {
            return
        }
        let snapshotView = tableView.snapshotView(afterScreenUpdates: true)
        if let snapshotView {
            view.addSubview(snapshotView)
            snapshotView.snp.makeConstraints { make in
                make.edges.equalTo(tableView)
            }
        }
        let contentOffset = tableView.contentOffset
        tableView.showsVerticalScrollIndicator = false
        tableView.setContentOffset(.zero, animated: false)
        tableView.layoutIfNeeded()
        defer {
            tableView.setContentOffset(contentOffset, animated: false)
            tableView.showsVerticalScrollIndicator = true
            snapshotView?.removeFromSuperview()
        }
        
        let statsIndexPath = IndexPath(item: StatsRow.bottomSeparator.rawValue,
                                       section: Section.stats.rawValue)
        let lastCell: UITableViewCell
        if viewModel.stats != nil, let cell = tableView.cellForRow(at: statsIndexPath) {
            lastCell = cell
        } else if let cell = tokenPriceChartCell {
            lastCell = cell
        } else {
            return
        }
        let height = floor(lastCell.convert(lastCell.bounds, to: tableView).maxY) + 10
        
        // `tableView.bounds` must be used as the canvas size.
        // Using other values will result in corruption on iOS 14.
        let renderer = UIGraphicsImageRenderer(bounds: tableView.bounds)
        let image = renderer.image { context in
            tableView.drawHierarchy(in: tableView.bounds, afterScreenUpdates: true)
        }
        
        let croppingRect = CGRect(x: 0, y: 0, width: tableView.bounds.width * image.scale, height: height * image.scale)
        guard let cgImage = image.cgImage?.cropping(to: croppingRect) else {
            return
        }
        let croppedImage = UIImage(cgImage: cgImage)
        let share = ShareMarketViewController(symbol: market.symbol, image: croppedImage)
        present(share, animated: true)
    }
    
    @objc private func reloadFromLocal() {
        DispatchQueue.global().async { [weak self, id] in
            let market = switch id {
            case .coin(let coinID):
                MarketDAO.shared.market(coinID: coinID)
            case .asset(let assetID):
                MarketDAO.shared.market(assetID: assetID)
            }
            guard let market else {
                return
            }
            let hasAlert = MarketAlertDAO.shared.alertExists(coinID: market.coinID)
            DispatchQueue.main.sync {
                guard let self else {
                    return
                }
                self.market = market
                self.hasAlert = hasAlert
                self.viewModel.update(market: market, tokens: [])
                self.tableView.reloadData()
                self.reloadTokens(market: market)
                self.updateFavoriteButtonImage()
            }
        }
    }
    
    private func updateFavoriteButtonImage() {
        guard let item = favoriteBarButtonItem else {
            return
        }
        if let market {
            if market.isFavorite {
                item.image = R.image.market_favorite_solid()?.withRenderingMode(.alwaysTemplate)
                item.tintColor = R.color.theme()
            } else {
                item.image = R.image.market_favorite_hollow()?.withRenderingMode(.alwaysTemplate)
                item.tintColor = R.color.icon_tint()
            }
        } else {
            item.image = nil
        }
    }
    
    private func reloadPriceChart(period: PriceHistoryPeriod) {
        DispatchQueue.global().async { [id, weak self] in
            let storage = switch id {
            case .coin(let id):
                MarketDAO.shared.priceHistory(coinID: id, period: period)
            case .asset(let id):
                MarketDAO.shared.priceHistory(assetID: id, period: period)
            }
            if let storage, let points = PriceHistory(storage: storage)?.chartViewPoints() {
                DispatchQueue.main.sync {
                    self?.reloadPriceChart(period: period, points: points)
                }
            }
            RouteAPI.priceHistory(id: id.value, period: period, queue: .global()) { result in
                switch result {
                case .success(let price):
                    if let storage = price.asStorage() {
                        MarketDAO.shared.savePriceHistory(storage)
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
    
    private func reloadPriceChart(period: PriceHistoryPeriod, points: [ChartView.Point]) {
        guard period == self.chartPeriod else {
            return
        }
        self.chartPoints = points
        if let cell = tokenPriceChartCell {
            cell.updateChart(points: points)
            if let market {
                cell.updatePriceAndChangeByMarket(price: market.localizedPrice, points: points)
            } else if let token = tokens?.first {
                cell.updatePriceAndChangeByMarket(price: token.localizedFiatMoneyPrice, points: points)
            }
        }
    }
    
    private func reloadTokens(market: Market) {
        guard let ids = market.assetIDs, !ids.isEmpty else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            func update(with tokens: [MixinTokenItem]) {
                DispatchQueue.main.sync {
                    guard let self else {
                        return
                    }
                    self.tokens = tokens
                    self.viewModel.update(market: market, tokens: tokens)
                    self.tableView.reloadData()
                }
            }
            
            let uniqueIDs = Set(ids)
            let tokens = TokenDAO.shared.tokenItems(with: uniqueIDs)
                .sorted { one, another in
                    one.decimalBalance > another.decimalBalance
                }
            update(with: tokens)
            if tokens.count != uniqueIDs.count {
                let missingAssetIDs = uniqueIDs.subtracting(tokens.map(\.assetID))
                Logger.general.debug(category: "MarketView", message: "Load missing asset: \(missingAssetIDs)")
                switch SafeAPI.assets(ids: missingAssetIDs) {
                case .success(let missingTokens):
                    let missingTokenItems = missingTokens.map { token in
                        let chain = ChainDAO.shared.chain(chainId: token.chainID)
                        return MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                    }
                    update(with: tokens + missingTokenItems)
                case .failure(let error):
                    Logger.general.debug(category: "MarketView", message: "\(error)")
                }
            }
        }
    }
    
    // `completion` is not called on failure
    private func pickSingleToken(completion: @escaping (MixinTokenItem) -> Void) {
        guard let tokens else {
            return
        }
        if tokens.count == 1 {
            completion(tokens[0])
        } else if tokens.count > 1, let name = market?.name {
            let selector = MarketTokenSelectorViewController(name: name, tokens: tokens) { index in
                completion(tokens[index])
            }
            present(selector, animated: true)
        }
    }
    
    private func requestEnableNotifications() {
        let tip = PopupTipViewController(tip: .notification)
        present(tip, animated: true)
    }
    
}

extension MarketViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension MarketViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .warning:
            isMalicious ? 1 : 0
        case .chart:
            1
        case .stats:
            viewModel.stats == nil ? 0 : StatsRow.allCases.count
        case .myBalance:
            viewModel.balance == nil ? 0 : MyBalanceRow.allCases.count
        case .infos:
            viewModel.infos.count + 2 // 2 for separators
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .warning:
            return tableView.dequeueReusableCell(withIdentifier: maliciousWarningReuseIdentifier, for: indexPath)
        case .chart:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_price_chart, for: indexPath)!
            if let market {
                cell.titleLabel.text = market.symbol
                cell.rankLabel.text = market.numberedRank
                cell.tokenIconView.setIcon(market: market)
                cell.updatePriceAndChangeByMarket(price: market.localizedPrice, points: chartPoints)
            } else if let token = tokens?.first {
                cell.titleLabel.text = token.symbol
                cell.rankLabel.text = nil
                cell.tokenIconView.setIcon(token: token)
                cell.updatePriceAndChangeByMarket(price: token.localizedFiatMoneyPrice, points: chartPoints)
            } else {
                cell.titleLabel.text = viewModel.symbol
                cell.rankLabel.text = nil
            }
            cell.rankLabel.isHidden = cell.rankLabel.text == nil
            cell.setPeriodSelection(period: chartPeriod)
            cell.updateChart(points: chartPoints)
            if market == nil {
                cell.tokenActions = []
            } else {
                if hasAlert {
                    cell.tokenActions = [.swap, .alert]
                } else {
                    cell.tokenActions = [.swap, .addAlert]
                }
            }
            cell.delegate = self
            cell.chartView.delegate = self
            cell.tokenActionView.delegate = self
            return cell
        case .stats:
            switch StatsRow(rawValue: indexPath.row)! {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = if let market {
                    market.name
                } else if let token = tokens?.first {
                    token.name
                } else {
                    nil
                }
                cell.disclosureIndicatorView.isHidden = true
                return cell
            case .marketCap:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_stats, for: indexPath)!
                cell.leftTitleLabel.text = R.string.localizable.market_cap().uppercased()
                cell.setLeftContent(text: viewModel.stats?.marketCap)
                cell.rightTitleLabel.text = R.string.localizable.vol_24h().uppercased()
                
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
                cell.disclosureIndicatorView.isHidden = tokens?.isEmpty ?? true
                return cell
            case .content:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_my_balance, for: indexPath)!
                if let balance = viewModel.balance {
                    cell.balanceLabel.text = balance.balance
                    cell.periodLabel.text = balance.period
                    cell.valueLabel.text = balance.value
                    cell.changeLabel.text = balance.change
                    switch balance.changeColor {
                    case .market(let color):
                        cell.changeLabel.marketColor = color
                    case .arbitrary(let color):
                        cell.changeLabel.textColor = color
                    }
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
        case .warning, .chart:
            return UITableView.automaticDimension
        case .stats:
            return switch StatsRow(rawValue: indexPath.row)! {
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
        case .warning:
            isMalicious ? 10 : .leastNormalMagnitude
        case .chart:
            10
        case .stats:
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
            pickSingleToken { [market] token in
                let pushingToken = (self.pushingViewController as? MixinTokenViewController)?.token
                if token.assetID == pushingToken?.assetID {
                    self.navigationController?.popViewController(animated: true)
                } else {
                    let controller = MixinTokenViewController(token: token, market: market)
                    self.navigationController?.pushViewController(controller, animated: true)
                    reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "market_detail"])
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
        case .week, .month, .year, .all:
            DateFormatter.shortDateOnly.string(from: point.date)
        }
    }
    
    func chartView(_ view: ChartView, didSelectPoint point: ChartView.Point) {
        guard let base = view.points.first else {
            return
        }
        tokenPriceChartCell?.updatePriceAndChangeByChart(base: base, now: point)
    }
    
    func chartViewDidCancelSelection(_ view: ChartView) {
        guard let cell = tokenPriceChartCell else {
            return
        }
        if let market {
            cell.tokenIconView.setIcon(market: market)
            cell.updatePriceAndChangeByMarket(price: market.localizedPrice, points: chartPoints)
        } else if let token = tokens?.first {
            cell.tokenIconView.setIcon(token: token)
            cell.updatePriceAndChangeByMarket(price: token.localizedFiatMoneyPrice, points: chartPoints)
        }
    }
    
}

extension MarketViewController: TokenPriceChartCell.Delegate {
    
    func tokenPriceChartCell(_ cell: TokenPriceChartCell, didSelectPeriod period: PriceHistoryPeriod) {
        chartPoints = nil
        self.chartPeriod = period
        reloadPriceChart(period: period)
    }
    
    func tokenPriceChartCellWantsToShowAlert(_ cell: TokenPriceChartCell) {
        guard let market else {
            return
        }
        let coin = MarketAlertCoin(market: market)
        let alert = CoinMarketAlertsViewController(coin: coin)
        navigationController?.pushViewController(alert, animated: true)
    }
    
    func tokenPriceChartCellWantsToAddAlert(_ cell: TokenPriceChartCell) {
        guard let market else {
            return
        }
        let coin = MarketAlertCoin(market: market)
        let addAlert = AddMarketAlertViewController(coin: coin)
        navigationController?.pushViewController(addAlert, animated: true)
    }
    
}

extension MarketViewController: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        guard let market, let actions = tokenPriceChartCell?.tokenActions else {
            return
        }
        switch actions[index] {
        case .swap:
            if tokens == nil {
                alert(R.string.localizable.swap_not_supported(market.symbol))
            } else {
                pickSingleToken { token in
                    let swap = MixinSwapViewController(
                        sendAssetID: AssetID.erc20USDT,
                        receiveAssetID: token.assetID,
                        referral: nil
                    )
                    self.navigationController?.pushViewController(swap, animated: true)
                    reporter.report(event: .tradeStart, tags: ["wallet": "main", "source": "market_detail"])
                }
            }
        case .alert:
            NotificationManager.shared.getAuthorized { isAuthorized in
                if isAuthorized {
                    let coin = MarketAlertCoin(market: market)
                    let alert = CoinMarketAlertsViewController(coin: coin)
                    self.navigationController?.pushViewController(alert, animated: true)
                } else {
                    self.requestEnableNotifications()
                }
            }
        case .addAlert:
            NotificationManager.shared.getAuthorized { isAuthorized in
                if isAuthorized {
                    let coin = MarketAlertCoin(market: market)
                    let addAlert = AddMarketAlertViewController(coin: coin)
                    self.navigationController?.pushViewController(addAlert, animated: true)
                } else {
                    self.requestEnableNotifications()
                }
            }
        }
    }
    
}

extension MarketViewController {
    
    private enum Identifier {
        
        case coin(String)
        case asset(String)
        
        var value: String {
            switch self {
            case .coin(let id):
                id
            case .asset(let id):
                id
            }
        }
        
    }
    
    private enum ReuseIdentifier {
        static let header = "header"
        static let emptyCell = "emtpy_cell"
    }
    
    private enum Section: Int, CaseIterable {
        case warning
        case chart
        case stats
        case myBalance
        case infos
    }
    
    private enum MyBalanceRow: Int, CaseIterable {
        case title
        case content
    }
    
    private enum StatsRow: Int, CaseIterable {
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
                    primaryContent: .notApplicable,
                    primaryContentColor: R.color.text_tertiary()!
                )
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
            
            init(market: Market) {
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
                if let value = Decimal(string: market.marketCap, locale: .enUSPOSIX), !value.isZero {
                    marketCap = NamedLargeNumberFormatter.string(number: value, currencyPrefix: true)
                } else {
                    marketCap = .notApplicable
                }
                let fiatMoneyVolume24H: String?
                if let totalVolume = Decimal(string: market.totalVolume, locale: .enUSPOSIX) {
                    fiatMoneyVolume24H = NamedLargeNumberFormatter.string(
                        number: totalVolume * Currency.current.decimalRate,
                        currencyPrefix: true
                    )
                } else {
                    fiatMoneyVolume24H = nil
                }
                
                self.high24H = high24H
                self.low24H = low24H
                self.marketCap = marketCap
                self.fiatMoneyVolume24H = fiatMoneyVolume24H
            }
            
        }
        
        struct Balance {
            
            enum Color {
                case market(MarketColor)
                case arbitrary(UIColor)
            }
            
            let balance: String
            let period: String
            let value: String
            let change: String
            let changeColor: Color
            
            init(balance: String, period: String, value: String, change: String, changeColor: Color) {
                self.balance = balance
                self.period = period
                self.value = value
                self.change = change
                self.changeColor = changeColor
            }
            
            func replacing(change: String, changeColor: Color) -> Balance {
                Balance(
                    balance: self.balance,
                    period: self.period,
                    value: self.value,
                    change: change,
                    changeColor: changeColor
                )
            }
            
        }
        
        let symbol: String
        
        private(set) var stats: Stats?
        private(set) var balance: Balance?
        private(set) var infos: [Info]
        
        private var basicInfos: [Info]
        private var marketInfos: [Info]
        
        init(market: Market) {
            let basicInfos = [
                Info(title: R.string.localizable.name().uppercased(), primaryContent: market.name),
                Info(title: R.string.localizable.symbol().uppercased(), primaryContent: market.symbol),
            ]
            let marketInfos = Info.marketInfos(market: market)
            
            self.stats = Stats(market: market)
            self.balance = nil
            self.infos = basicInfos + marketInfos
            
            self.symbol = market.symbol
            
            self.basicInfos = basicInfos
            self.marketInfos = marketInfos
        }
        
        init(token: any ValuableToken) {
            let basicInfos = [
                Info(title: R.string.localizable.name().uppercased(), primaryContent: token.name),
                Info(title: R.string.localizable.symbol().uppercased(), primaryContent: token.symbol),
            ]
            let marketInfos: [Info] = []
            
            self.stats = nil
            self.balance = Balance(
                balance: token.localizedBalanceWithSymbol,
                period: R.string.localizable.hours_count_short(24),
                value: token.estimatedFiatMoneyBalance,
                change: "",
                changeColor: .arbitrary(.clear)
            )
            self.infos = basicInfos
            
            self.symbol = token.symbol
            
            self.basicInfos = basicInfos
            self.marketInfos = marketInfos
        }
        
        func updateWithMarketNotFound() {
            self.stats = nil
            if let balance {
                self.balance = balance.replacing(change: .notApplicable, changeColor: .arbitrary(R.color.text_quaternary()!))
            }
            self.marketInfos = [
                Info.contentNotApplicable(title: R.string.localizable.market_cap().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.circulation_supply().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.total_supply().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.all_time_high().uppercased()),
                Info.contentNotApplicable(title: R.string.localizable.all_time_low().uppercased()),
            ]
            self.infos = basicInfos + marketInfos
        }
        
        func update(market: Market, tokens: [MixinTokenItem]) {
            self.stats = Stats(market: market)
            
            self.balance = {
                let balance: Decimal
                if tokens.count == 1 {
                    balance = tokens[0].decimalBalance
                } else if tokens.count > 1 {
                    balance = tokens.reduce(0) { result, item in
                        result + item.decimalBalance
                    }
                } else {
                    balance = 0
                }
                
                var change: String
                let changeColor: Balance.Color
                if let priceChange24H = Decimal(string: market.priceChange24H, locale: .enUSPOSIX) {
                    change = CurrencyFormatter.localizedString(
                        from: priceChange24H * balance * Currency.current.decimalRate,
                        format: .fiatMoneyPrice,
                        sign: .always,
                        symbol: .currencySymbol
                    )
                    if let priceChangePercentage24H = Decimal(string: market.priceChangePercentage24H, locale: .enUSPOSIX),
                       let percent = NumberFormatter.percentage.string(decimal: priceChangePercentage24H / 100)
                    {
                        change += " (\(percent))"
                    }
                    changeColor = .market(.byValue(priceChange24H))
                } else {
                    change = ""
                    changeColor = .arbitrary(.clear)
                }
                
                return Balance(
                    balance: CurrencyFormatter.localizedString(
                        from: balance,
                        format: .precision,
                        sign: .never,
                        symbol: .custom(symbol)
                    ),
                    period: R.string.localizable.hours_count_short(24),
                    value: "≈ " + CurrencyFormatter.localizedString(
                        from: balance * market.decimalPrice * Currency.current.decimalRate,
                        format: .fiatMoney,
                        sign: .never,
                        symbol: .currencySymbol
                    ),
                    change: change,
                    changeColor: changeColor
                )
            }()
            
            self.marketInfos = Info.marketInfos(market: market)
            self.infos = basicInfos + marketInfos
        }
        
    }
    
    private final class MarketPeriodicRequester {
        
        private let id: String
        private let refreshInterval: TimeInterval = 30
        private let onNotFound: () -> Void
        
        private var isRunning = false
        private var lastReloadingDate: Date = .distantPast
        
        private weak var timer: Timer?
        
        init(id: String, onNotFound: @escaping () -> Void) {
            self.id = id
            self.onNotFound = onNotFound
        }
        
        func start() {
            assert(Thread.isMainThread)
            guard !isRunning else {
                return
            }
            isRunning = true
            let delay = lastReloadingDate.addingTimeInterval(refreshInterval).timeIntervalSinceNow
            if delay <= 0 {
                Logger.general.debug(category: "MarketRequester", message: "Load now")
                requestData()
            } else {
                Logger.general.debug(category: "MarketRequester", message: "Load after \(delay)s")
                timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.requestData()
                }
            }
        }
        
        func pause() {
            assert(Thread.isMainThread)
            Logger.general.debug(category: "MarketRequester", message: "Pause loading")
            isRunning = false
            timer?.invalidate()
        }
        
        private func requestData() {
            assert(Thread.isMainThread)
            timer?.invalidate()
            Logger.general.debug(category: "MarketRequester", message: "Request data")
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            RouteAPI.markets(id: id, queue: .global()) { [refreshInterval, onNotFound] result in
                switch result {
                case let .success(market):
                    MarketDAO.shared.save(market: market)
                    Logger.general.debug(category: "MarketRequester", message: "Saved")
                    DispatchQueue.main.async {
                        Logger.general.debug(category: "MarketRequester", message: "Reload after \(refreshInterval)s")
                        self.lastReloadingDate = Date()
                        self.timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: false) { [weak self] _ in
                            self?.requestData()
                        }
                    }
                case .failure(.response(.notFound)):
                    DispatchQueue.main.async(execute: onNotFound)
                case let .failure(error):
                    Logger.general.debug(category: "MarketRequester", message: "\(error)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.requestData()
                    }
                }
            }
        }
        
    }
    
}
