import UIKit
import MixinServices

final class ExploreMarketViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private var marketsRequester: MarketPeriodicRequester!
    private var favoritesRequester: MarketPeriodicRequester!
    private var globalMarketViewModels: [GlobalMarketViewModel] = []
    private var markets: [FavorableMarket] = []
    private var favoriteMarkets: [FavorableMarket]?
    private var category = AppGroupUserDefaults.User.marketCategory
    private var order: Market.OrderingExpression = .marketCap(.descending)
    private var changePeriod: Market.ChangePeriod = .sevenDays
    private var limit: Market.Limit? = .top100
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.register(R.nib.exploreGlobalMarketCell)
        collectionView.register(R.nib.exploreMarketTokenCell)
        collectionView.register(R.nib.watchlistEmptyCell)
        collectionView.register(R.nib.exploreMarketHeaderView, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.backgroundColor = R.color.background()
        collectionView.contentInset.bottom = 20
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        collectionView.dataSource = self
        collectionView.delegate = self
        
        reloadGlobalMarket(overwrites: false)
        reloadMarketsFromLocal()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll(_:)), name: Currency.currentCurrencyDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesDatabaseDidUpdate(_:)), name: PropertiesDAO.propertyDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteChanged(_:)), name: MarketDAO.favoriteNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteChanged(_:)), name: MarketDAO.unfavoriteNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadMarketsFromLocal), name: MarketDAO.didUpdateNotification, object: nil)
        
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
    
    @objc private func reloadAll(_ notification: Notification) {
        reloadGlobalMarket(overwrites: true)
        reloadMarketsFromLocal()
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
        reloadMarketsFromLocal()
    }
    
    @objc private func reloadMarketsFromLocal() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.reloadMarketsFromLocal()
            }
            return
        }
        DispatchQueue.global().async { [weak self, category, order, limit] in
            let markets = MarketDAO.shared.markets(category: category, order: order, limit: limit)
            DispatchQueue.main.async {
                guard
                    let self,
                    self.category == category,
                    self.order == order,
                    self.limit == limit
                else {
                    return
                }
                switch category {
                case .all:
                    self.markets = markets
                case .favorite:
                    self.favoriteMarkets = markets
                }
                self.collectionView.reloadData()
            }
        }
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
                self.collectionView.reloadData()
            }
        }
    }
    
}

extension ExploreMarketViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        switch category {
        case .all:
            if markets.isEmpty {
                Section.allCases.count - 2
            } else {
                Section.allCases.count - 1
            }
        case .favorite:
            Section.allCases.count
        }
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
            if let favoriteMarkets, favoriteMarkets.isEmpty {
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
            cell.secondaryLabel.marketColor = info.secondaryColor
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
        view.delegate = self
        return view
    }
    
}

extension ExploreMarketViewController: UICollectionViewDelegate {
    
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
                let controller = MarketViewController.contained(market: market, pushingViewController: self)
                navigationController?.pushViewController(controller, animated: true)
            }
        }
    }
    
}

extension ExploreMarketViewController: ExploreMarketHeaderView.Delegate {
    
    func exploreMarketHeaderView(
        _ view: ExploreMarketHeaderView,
        didSwitchToCategory category: Market.Category,
        limit: Market.Limit?
    ) {
        self.category = category
        self.limit = limit
        reloadMarketsFromLocal()
    }
    
    func exploreMarketHeaderView(_ view: ExploreMarketHeaderView, didSwitchToOrdering order: Market.OrderingExpression) {
        self.order = order
        reloadMarketsFromLocal()
    }
    
}

extension ExploreMarketViewController: ExploreMarketTokenCell.Delegate {
    
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

extension ExploreMarketViewController {
    
    private enum Section: Int, CaseIterable {
        case global
        case coins
        case noFavoriteIndicator
    }
    
    private struct GlobalMarketViewModel {
        
        let caption: String
        let primary: String?
        let secondary: String?
        let secondaryColor: MarketColor
        
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
                    secondaryColor: .byValue(market.marketCapChangePercentage)
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
                    secondaryColor: .byValue(market.volumeChangePercentage)
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
        
        private static var lastReloadingDate: Date = .distantPast
        
        private let category: Market.Category
        private let modelName: String
        private let refreshInterval: TimeInterval = 30
        
        private var isRunning = false
        
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
            let delay = Self.lastReloadingDate.addingTimeInterval(refreshInterval).timeIntervalSinceNow
            if delay <= 0 {
                Logger.general.debug(category: "MarketPeriodicRequester", message: "Load \(modelName) now")
                requestData()
            } else {
                Logger.general.debug(category: "MarketPeriodicRequester", message: "Load \(modelName) after \(delay)s")
                timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.requestData()
                }
            }
        }
        
        func pause() {
            assert(Thread.isMainThread)
            Logger.general.debug(category: "MarketPeriodicRequester", message: "Pause loading \(modelName)")
            isRunning = false
            timer?.invalidate()
        }
        
        private func requestData() {
            assert(Thread.isMainThread)
            timer?.invalidate()
            Logger.general.debug(category: "MarketPeriodicRequester", message: "Request \(modelName)")
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            RouteAPI.markets(category: category, queue: .global()) { [refreshInterval, category, modelName] result in
                switch result {
                case let .success(markets):
                    switch category {
                    case .all:
                        MarketDAO.shared.saveMarketsAndReplaceRanks(markets: markets)
                    case .favorite:
                        MarketDAO.shared.replaceFavoriteMarkets(markets: markets)
                    }
                    Logger.general.debug(category: "MarketPeriodicRequester", message: "Saved \(markets.count) \(modelName)")
                    DispatchQueue.main.async {
                        Logger.general.debug(category: "MarketPeriodicRequester", message: "Reload \(modelName) after \(refreshInterval)s")
                        Self.lastReloadingDate = Date()
                        self.timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: false) { [weak self] _ in
                            self?.requestData()
                        }
                    }
                case let .failure(error):
                    Logger.general.debug(category: "MarketPeriodicRequester", message: "Load \(modelName): \(error)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.requestData()
                    }
                }
            }
        }
        
    }
    
}
