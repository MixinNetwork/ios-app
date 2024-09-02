import UIKit
import MixinServices

final class ExploreMarketViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private var requester: MarketPeriodicRequester!
    private var globalMarketViewModels: [GlobalMarketViewModel] = []
    private var markets: [FavorableMarket] = []
    private var favoriteMarkets: [FavorableMarket]?
    private var category = AppGroupUserDefaults.User.marketCategory
    private var order: Market.OrderingExpression = .marketCap(.descending)
    private var changePeriod: Market.ChangePeriod = .sevenDays
    private var limit: Market.Limit = .top100
    
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
            case .info:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading: 6, bottom: 0, trailing: 6)
                let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(132), heightDimension: .absolute(90))
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 0, trailing: 12)
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
        collectionView.backgroundColor = R.color.background()
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        collectionView.register(R.nib.exploreGlobalMarketCell)
        collectionView.register(R.nib.exploreMarketTokenCell)
        collectionView.register(R.nib.watchlistEmptyCell)
        collectionView.register(R.nib.exploreMarketHeaderView, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.dataSource = self
        collectionView.contentInset.bottom = 20
        
        requester = MarketPeriodicRequester() { [weak self] in
            self?.reloadMarkets(overwrites: true)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll(_:)), name: Currency.currentCurrencyDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesDatabaseDidUpdate(_:)), name: PropertiesDAO.propertyDidUpdateNotification, object: nil)
        
        reloadGlobalMarket(overwrites: false)
        reloadMarkets(overwrites: false)
        syncWatchlistFromRemote()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ConcurrentJobQueue.shared.addJob(job: ReloadGlobalMarketJob())
        requester.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        requester.pause()
    }
    
    @objc private func reloadAll(_ notification: Notification) {
        reloadGlobalMarket(overwrites: true)
        reloadMarkets(overwrites: true)
    }
    
    @objc private func propertiesDatabaseDidUpdate(_ notification: Notification) {
        guard notification.userInfo?[PropertiesDAO.Key.globalMarket] != nil else {
            return
        }
        reloadGlobalMarket(overwrites: true)
    }
    
    private func syncWatchlistFromRemote() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        RouteAPI.markets(category: .favorite, queue: .global()) { [weak self] result in
            switch result {
            case let .success(markets):
                let now = Date().toUTCString()
                let favoredMarkets = markets.map { market in
                    FavoredMarket(coinID: market.coinID, isFavored: true, createdAt: now)
                }
                MarketDAO.shared.replaceFavoredMarkets(with: favoredMarkets) {
                    self?.reloadMarkets(overwrites: true)
                }
            case let .failure(error):
                Logger.general.debug(category: "Web3Market", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.syncWatchlistFromRemote()
                }
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
    
    private func reloadMarkets(overwrites: Bool) {
        DispatchQueue.global().async { [weak self, category, order, limit] in
            let markets = MarketDAO.shared.markets(category: category, order: order, limit: limit)
            DispatchQueue.main.async {
                guard
                    let self,
                    self.markets.isEmpty || overwrites,
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
        case .info:
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
        case .info:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_global_market, for: indexPath)!
            let info = globalMarketViewModels[indexPath.item]
            cell.captionLabel.text = info.caption
            cell.primaryLabel.text = info.primary
            cell.secondaryLabel.text = info.secondary
            cell.secondaryLabel.textColor = info.secondaryColor
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

extension ExploreMarketViewController: ExploreMarketHeaderView.Delegate {
    
    func exploreMarketHeaderView(_ view: ExploreMarketHeaderView, didSwitchToLimit limit: Market.Limit) {
        self.limit = limit
        reloadMarkets(overwrites: true)
    }
    
    func exploreMarketHeaderView(_ view: ExploreMarketHeaderView, didSwitchToCategory category: Market.Category) {
        self.category = category
        reloadMarkets(overwrites: true)
    }
    
    func exploreMarketHeaderView(_ view: ExploreMarketHeaderView, didSwitchToOrdering order: Market.OrderingExpression) {
        self.order = order
        reloadMarkets(overwrites: true)
    }
    
}

extension ExploreMarketViewController: ExploreMarketTokenCell.Delegate {
    
    func exploreTokenMarketCellWantsToggleFavorite(_ cell: ExploreMarketTokenCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        collectionView.isUserInteractionEnabled = false
        cell.favoriteActivityIndicatorView.startAnimating()
        let market = switch category {
        case .all:
            markets[indexPath.item]
        case .favorite:
            favoriteMarkets![indexPath.item]
        }
        
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
                        MarketDAO.shared.unfavorite(coinID: market.coinID)
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
                        MarketDAO.shared.favorite(coinID: market.coinID)
                    }
                    cell.isFavorited = true
                    updateModel(isFavorited: true)
                case .failure(let error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
    }
    
}

extension ExploreMarketViewController {
    
    private enum Section: Int, CaseIterable {
        case info
        case coins
        case noFavoriteIndicator
    }
    
    private struct GlobalMarketViewModel {
        
        let caption: String
        let primary: String?
        let secondary: String?
        let secondaryColor: UIColor?
        
        static func viewModels(market: GlobalMarket) -> [GlobalMarketViewModel] {
            [
                GlobalMarketViewModel(
                    caption: R.string.localizable.market_cap(),
                    primary: NamedLargeNumberFormatter.string(
                        number: market.marketCap * Currency.current.decimalRate,
                        currencyPrefix: true
                    ),
                    secondary: NumberFormatter.percentage.string(
                        decimal: market.marketCapChangePercentage / 100
                    ),
                    secondaryColor: market.marketCapChangePercentage >= 0 ? .priceRising : .priceFalling
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
                    secondaryColor: market.volumeChangePercentage >= 0 ? .priceRising : .priceFalling
                ),
                GlobalMarketViewModel(
                    caption: R.string.localizable.dominance(),
                    primary: NumberFormatter.percentage.string(
                        decimal: market.dominancePercentage / 100
                    ),
                    secondary: market.dominance,
                    secondaryColor: R.color.text_secondary()
                ),
            ]
        }
        
    }
    
    private final class MarketPeriodicRequester {
        
        private static var lastReloadingDate: Date = .distantPast
        
        private let refreshInterval: TimeInterval = 5 * .minute
        
        private var isRunning = false
        private var onSuccess: (() -> Void)?
        
        private weak var timer: Timer?
        
        init(onSuccess: @escaping () -> Void) {
            self.onSuccess = onSuccess
        }
        
        func start() {
            assert(Thread.isMainThread)
            guard !isRunning else {
                return
            }
            isRunning = true
            let delay = Self.lastReloadingDate.addingTimeInterval(refreshInterval).timeIntervalSinceNow
            if delay <= 0 {
                Logger.general.debug(category: "MarketPeriodicRequester", message: "Start now")
                requestMarkets()
            } else {
                Logger.general.debug(category: "MarketPeriodicRequester", message: "Start after \(delay)s")
                timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.requestMarkets()
                }
            }
        }
        
        func pause() {
            assert(Thread.isMainThread)
            Logger.general.debug(category: "MarketPeriodicRequester", message: "Pause")
            isRunning = false
            timer?.invalidate()
        }
        
        private func requestMarkets() {
            assert(Thread.isMainThread)
            timer?.invalidate()
            Logger.general.debug(category: "MarketPeriodicRequester", message: "Request")
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            RouteAPI.markets(category: .all, queue: .global()) { [refreshInterval] result in
                switch result {
                case let .success(markets):
                    MarketDAO.shared.save(markets: markets) {
                        Logger.general.debug(category: "MarketPeriodicRequester", message: "Markets saved")
                        DispatchQueue.main.async {
                            self.onSuccess?()
                        }
                    }
                    DispatchQueue.main.async {
                        Logger.general.debug(category: "MarketPeriodicRequester", message: "Reload markets after \(refreshInterval)s")
                        Self.lastReloadingDate = Date()
                        self.timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: false) { [weak self] _ in
                            self?.requestMarkets()
                        }
                    }
                case let .failure(error):
                    Logger.general.debug(category: "MarketPeriodicRequester", message: "\(error)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.requestMarkets()
                    }
                }
            }
        }
        
    }
    
}
