import UIKit
import MixinServices

final class MarketDashboardViewController: UIViewController {
    
    private let queue = OperationQueue()
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private var collectionView: UICollectionView!
    
    private var marketsRequester: MarketPeriodicRequester!
    private var favoritesRequester: MarketPeriodicRequester!
    
    private var globalMarketViewModels: [GlobalMarketViewModel] = []
    
    private var category: Market.Category = AppGroupUserDefaults.User.marketCategory {
        didSet {
            AppGroupUserDefaults.User.marketCategory = category
        }
    }
    private var order: Market.OrderingExpression = .marketCap(.descending)
    private var limit: Market.Limit? = .top100
    private var changePeriod: Market.ChangePeriod = AppGroupUserDefaults.User.marketChangePeriod {
        didSet {
            AppGroupUserDefaults.User.marketChangePeriod = changePeriod
        }
    }
    private var markets: [FavorableMarket] = []
    private var favoriteMarkets: [FavorableMarket]?
    
    private weak var searchViewController: UIViewController?
    private weak var searchViewCenterYConstraint: NSLayoutConstraint?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleView = HomeNavigationTitleView()
        view.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }
        titleView.titleLabel.text = R.string.localizable.markets()
        titleView.searchButton.addTarget(self, action: #selector(searchCoins(_:)), for: .touchUpInside)
        titleView.scanButton.addTarget(self, action: #selector(scanQRCode(_:)), for: .touchUpInside)
        titleView.settingButton.addTarget(self, action: #selector(openSettings(_:)), for: .touchUpInside)
        
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, environment) in
            switch Section(rawValue: sectionIndex)! {
            case .global:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading: 6, bottom: 0, trailing: 6)
                let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(132), heightDimension: .absolute(90))
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
                section.orthogonalScrollingBehavior = .groupPaging
                return section
            case .coins:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(94)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                header.pinToVisibleBounds = true
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [header]
                section.interGroupSpacing = 20
                return section
            case .noFavoriteIndicator:
                let margin: CGFloat = switch ScreenHeight.current {
                case .extraLong:
                    130
                case .long:
                    100
                case .medium:
                    80
                case .short:
                    60
                }
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(margin + 120))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
        }
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.register(R.nib.exploreGlobalMarketCell)
        collectionView.register(R.nib.exploreMarketTokenCell)
        collectionView.register(R.nib.watchlistEmptyCell)
        collectionView.register(R.nib.exploreMarketHeaderView, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.backgroundColor = R.color.background()
        collectionView.contentInset.bottom = 20
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleView.snp.bottom)
        }
        self.collectionView = collectionView
        collectionView.dataSource = self
        collectionView.delegate = self
        
        reloadGlobalMarket(overwrites: false)
        reloadMarketsWithCurrentSettings()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll(_:)), name: Currency.currentCurrencyDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesDatabaseDidUpdate(_:)), name: PropertiesDAO.propertyDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteChanged(_:)), name: MarketDAO.favoriteNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteChanged(_:)), name: MarketDAO.unfavoriteNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadMarketsWithCurrentSettings), name: MarketDAO.didUpdateNotification, object: nil)
        
        marketsRequester = MarketPeriodicRequester(category: .all)
        favoritesRequester = MarketPeriodicRequester(category: .favorite)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ConcurrentJobQueue.shared.addJob(job: ReloadGlobalMarketJob())
        marketsRequester.start()
        favoritesRequester.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        marketsRequester.pause()
        favoritesRequester.pause()
    }
    
    func cancelSearching(animated: Bool) {
        guard let searchViewController, let searchViewCenterYConstraint else {
            return
        }
        let removeSearch = {
            searchViewController.willMove(toParent: nil)
            searchViewController.view.removeFromSuperview()
            searchViewController.removeFromParent()
        }
        if animated {
            searchViewCenterYConstraint.constant = hiddenSearchTopMargin
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                searchViewController.view.alpha = 0
            } completion: { _ in
                removeSearch()
            }
        } else {
            removeSearch()
        }
    }
    
    @objc private func searchCoins(_ sender: Any) {
        let searchViewController = SearchMarketViewController()
        addChild(searchViewController)
        searchViewController.view.alpha = 0
        view.addSubview(searchViewController.view)
        searchViewController.view.snp.makeConstraints { make in
            make.size.centerX.equalToSuperview()
        }
        let searchViewCenterYConstraint = searchViewController.view.centerYAnchor
            .constraint(equalTo: view.centerYAnchor, constant: hiddenSearchTopMargin)
        searchViewCenterYConstraint.isActive = true
        searchViewController.didMove(toParent: self)
        view.layoutIfNeeded()
        searchViewCenterYConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            searchViewController.view.alpha = 1
        }
        self.searchViewController = searchViewController
        self.searchViewCenterYConstraint = searchViewCenterYConstraint
    }
    
    @objc private func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushQRCodeScannerViewController()
    }
    
    @objc private func openSettings(_ sender: Any) {
        let settings = SettingsViewController()
        navigationController?.pushViewController(settings, animated: true)
    }
    
    @objc private func reloadAll(_ notification: Notification) {
        reloadGlobalMarket(overwrites: true)
        reloadMarketsWithCurrentSettings()
    }
    
    @objc private func propertiesDatabaseDidUpdate(_ notification: Notification) {
        guard notification.userInfo?[PropertiesDAO.Key.globalMarket] != nil else {
            return
        }
        reloadGlobalMarket(overwrites: true)
    }
    
    @objc private func favoriteChanged(_ notification: Notification) {
        guard let coinID = notification.userInfo?[MarketDAO.coinIDUserInfoKey] as? String else {
            return
        }
        guard category == .favorite || markets.contains(where: { $0.coinID == coinID }) else {
            return
        }
        reloadMarketsWithCurrentSettings()
    }
    
    @objc private func reloadMarketsWithCurrentSettings() {
        reloadMarkets(category: category, order: order, limit: limit)
    }
    
    private func reloadGlobalMarket(overwrites: Bool) {
        DispatchQueue.global().async { [weak self] in
            guard let market: GlobalMarket = PropertiesDAO.shared.value(forKey: .globalMarket) else {
                return
            }
            DispatchQueue.main.async {
                guard let self, self.globalMarketViewModels.isEmpty || overwrites else {
                    return
                }
                self.globalMarketViewModels = GlobalMarketViewModel.viewModels(market: market)
                self.reloadCollectionView(sections: [.global])
            }
        }
    }
    
    private func reloadMarkets(
        category: Market.Category,
        order: Market.OrderingExpression,
        limit: Market.Limit?
    ) {
        queue.cancelAllOperations()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let markets = MarketDAO.shared.markets(category: category, order: order, limit: limit)
            DispatchQueue.main.sync {
                guard !op.isCancelled, let self else {
                    return
                }
                self.category = category
                self.order = order
                self.limit = limit
                switch category {
                case .all:
                    self.markets = markets
                case .favorite:
                    self.favoriteMarkets = markets
                }
                self.reloadCollectionView(sections: [.coins, .noFavoriteIndicator])
            }
        }
        queue.addOperation(op)
    }
    
    private func reloadCollectionView(sections: [Section]) {
        let sections = IndexSet(sections.map(\.rawValue))
        UIView.performWithoutAnimation {
            collectionView.reloadSections(sections)
        }
    }
    
}

extension MarketDashboardViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .global:
            globalMarketViewModels.count
        case .coins:
            switch category {
            case .all:
                markets.count
            case .favorite:
                favoriteMarkets?.count ?? 0
            }
        case .noFavoriteIndicator:
            if category == .favorite, let favoriteMarkets, favoriteMarkets.isEmpty {
                1 // Empty indicator
            } else {
                0
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .global:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_global_market, for: indexPath)!
            let info = globalMarketViewModels[indexPath.item]
            cell.captionLabel.text = info.caption
            cell.primaryLabel.text = info.primary
            cell.secondaryLabel.text = info.secondary
            switch info.secondaryColor {
            case .market(let color):
                cell.secondaryLabel.marketColor = color
            case .arbitrary(let color):
                cell.secondaryLabel.textColor = color
            }
            return cell
        case .coins:
            let markets = switch category {
            case .all:
                markets
            case .favorite:
                favoriteMarkets ?? []
            }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_market_token, for: indexPath)!
            let market = markets[indexPath.item]
            cell.reloadData(market: market, changePeriod: changePeriod)
            cell.delegate = self
            return cell
        case .noFavoriteIndicator:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.watchlist_empty, for: indexPath)!
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.explore_market_header, for: indexPath)!
        view.limit = limit
        view.category = category
        view.order = order
        view.changePeriod = changePeriod
        view.delegate = self
        return view
    }
    
}

extension MarketDashboardViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .global, .noFavoriteIndicator:
            break
        case .coins:
            let markets = switch category {
            case .all:
                markets
            case .favorite:
                favoriteMarkets
            }
            if let market = markets?[indexPath.item] {
                let controller = MarketViewController(market: market)
                controller.pushingViewController = self
                navigationController?.pushViewController(controller, animated: true)
            }
        }
    }
    
}

extension MarketDashboardViewController: ExploreMarketHeaderView.Delegate {
    
    func exploreMarketHeaderView(
        _ view: ExploreMarketHeaderView,
        didSwitchToCategory category: Market.Category,
        limit: Market.Limit?
    ) {
        reloadMarkets(category: category, order: order, limit: limit)
    }
    
    func exploreMarketHeaderView(
        _ view: ExploreMarketHeaderView,
        didSwitchToOrdering order: Market.OrderingExpression,
        changePeriod period: Market.ChangePeriod
    ) {
        self.changePeriod = period
        if self.order != order {
            reloadMarkets(category: category, order: order, limit: limit)
        } else {
            reloadCollectionView(sections: [.coins, .noFavoriteIndicator])
        }
    }
    
}

extension MarketDashboardViewController: ExploreMarketTokenCell.Delegate {
    
    func exploreTokenMarketCellWantsToggleFavorite(_ cell: ExploreMarketTokenCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let market = switch category {
        case .all:
            markets[indexPath.item]
        case .favorite:
            favoriteMarkets?[indexPath.item]
        }
        guard let market else {
            assertionFailure()
            return
        }
        collectionView.isUserInteractionEnabled = false
        cell.favoriteActivityIndicatorView.startAnimating()
        func updateModel(isFavorited: Bool) {
            switch category {
            case .all:
                markets[indexPath.item].isFavorite = isFavorited
            case .favorite:
                favoriteMarkets![indexPath.item].isFavorite = isFavorited
            }
        }
        
        if market.isFavorite {
            RouteAPI.unfavoriteMarket(coinID: market.coinID) { [weak self] result in
                cell.favoriteActivityIndicatorView.stopAnimating()
                self?.collectionView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        MarketDAO.shared.unfavorite(coinID: market.coinID, sendNotification: false)
                    }
                    cell.isFavorited = false
                    updateModel(isFavorited: false)
                case .failure(let error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        } else {
            RouteAPI.favoriteMarket(coinID: market.coinID) { [weak self] result in
                cell.favoriteActivityIndicatorView.stopAnimating()
                self?.collectionView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        MarketDAO.shared.favorite(coinID: market.coinID, sendNotification: false)
                    }
                    cell.isFavorited = true
                    updateModel(isFavorited: true)
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.watchlist_add_desc(market.symbol))
                case .failure(let error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
    }
    
}

extension MarketDashboardViewController {
    
    private enum Section: Int, CaseIterable {
        case global
        case coins
        case noFavoriteIndicator
    }
    
    private struct GlobalMarketViewModel {
        
        enum Color {
            case market(MarketColor)
            case arbitrary(UIColor)
        }
        
        let caption: String
        let primary: String?
        let secondary: String?
        let secondaryColor: Color
        
        static func viewModels(market: GlobalMarket) -> [GlobalMarketViewModel] {
            [
                GlobalMarketViewModel(
                    caption: R.string.localizable.global_market_cap(),
                    primary: NamedLargeNumberFormatter.string(
                        number: market.marketCap * Currency.current.decimalRate,
                        currencyPrefix: true
                    ),
                    secondary: NumberFormatter.percentage.string(
                        decimal: market.marketCapChangePercentage / 100
                    ),
                    secondaryColor: .market(.byValue(market.marketCapChangePercentage))
                ),
                GlobalMarketViewModel(
                    caption: R.string.localizable.volume_24h(),
                    primary: NamedLargeNumberFormatter.string(
                        number: market.volume * Currency.current.decimalRate,
                        currencyPrefix: true
                    ),
                    secondary: NumberFormatter.percentage.string(
                        decimal: market.volumeChangePercentage / 100
                    ),
                    secondaryColor: .market(.byValue(market.volumeChangePercentage))
                ),
                GlobalMarketViewModel(
                    caption: R.string.localizable.dominance(),
                    primary: NumberFormatter.percentage.string(
                        decimal: market.dominancePercentage / 100
                    ),
                    secondary: market.dominance,
                    secondaryColor: .arbitrary(R.color.text_secondary()!)
                ),
            ]
        }
        
    }
    
    private final class MarketPeriodicRequester {
        
        private let category: Market.Category
        private let modelName: String
        private let refreshInterval: TimeInterval = 30
        
        private var isRunning = false
        private var lastReloadingDate: Date = .distantPast
        
        private weak var timer: Timer?
        
        init(category: Market.Category) {
            self.category = category
            self.modelName = switch category {
            case .all:
                "markets"
            case .favorite:
                "favorites"
            }
        }
        
        func start() {
            assert(Thread.isMainThread)
            guard !isRunning else {
                return
            }
            isRunning = true
            let delay = lastReloadingDate.addingTimeInterval(refreshInterval).timeIntervalSinceNow
            if delay <= 0 {
                Logger.general.debug(category: "ExploreMarketRequester", message: "Load \(modelName) now")
                requestData()
            } else {
                Logger.general.debug(category: "ExploreMarketRequester", message: "Load \(modelName) after \(delay)s")
                scheduleNextRequestIfRunning(timeInterval: delay)
            }
        }
        
        func pause() {
            assert(Thread.isMainThread)
            Logger.general.debug(category: "ExploreMarketRequester", message: "Pause loading \(modelName)")
            isRunning = false
            timer?.invalidate()
        }
        
        private func requestData() {
            assert(Thread.isMainThread)
            timer?.invalidate()
            Logger.general.debug(category: "ExploreMarketRequester", message: "Request \(modelName)")
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            RouteAPI.markets(category: category, queue: .global()) { [weak self, refreshInterval, category, modelName] result in
                switch result {
                case let .success(markets):
                    switch category {
                    case .all:
                        MarketDAO.shared.saveMarketsAndReplaceRanks(markets: markets)
                    case .favorite:
                        MarketDAO.shared.replaceFavoriteMarkets(markets: markets)
                    }
                    Logger.general.debug(category: "ExploreMarketRequester", message: "Saved \(markets.count) \(modelName)")
                    DispatchQueue.main.async {
                        Logger.general.debug(category: "ExploreMarketRequester", message: "Reload \(modelName) after \(refreshInterval)s")
                        if let self {
                            self.lastReloadingDate = Date()
                            self.scheduleNextRequestIfRunning(timeInterval: refreshInterval)
                        }
                    }
                case let .failure(error):
                    Logger.general.debug(category: "ExploreMarketRequester", message: "Load \(modelName): \(error)")
                    DispatchQueue.main.async {
                        self?.scheduleNextRequestIfRunning(timeInterval: 3)
                    }
                }
            }
        }
        
        private func scheduleNextRequestIfRunning(timeInterval: TimeInterval) {
            guard isRunning else {
                return
            }
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.requestData()
            }
        }
        
    }
    
}
