import UIKit
import MixinServices

final class ExploreMarketViewController: UIViewController {
    
    private static var lastReloadingDate: Date = .distantPast
    
    private let refreshInterval: TimeInterval = 5 * .minute
    
    private var collectionView: UICollectionView!
    private var infos: [MarketInfo] = []
    private var markets: [FavorableMarket] = []
    private var favoriteMarkets: [FavorableMarket]?
    private var category = AppGroupUserDefaults.User.marketCategory
    private var order: Market.OrderingExpression = .marketCap(.descending)
    private var limit: Market.Limit = .top100
    
    private weak var timer: Timer?
    
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
                let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 0, trailing: 12)
                section.orthogonalScrollingBehavior = .groupPaging
                return section
            case .coins:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(94)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    )
                ]
                section.contentInsets = switch ScreenWidth.current {
                case .long:
                    NSDirectionalEdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30)
                case .medium:
                    NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
                case .short:
                    NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                }
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
        collectionView.register(R.nib.web3MarketInfoCell)
        collectionView.register(R.nib.web3TokenMarketCell)
        collectionView.register(R.nib.watchlistEmptyCell)
        collectionView.register(R.nib.web3MarketHeaderView, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.dataSource = self
        DispatchQueue.global().async { [weak self] in
            guard let market: GlobalMarket = PropertiesDAO.shared.value(forKey: .globalMarket) else {
                return
            }
            DispatchQueue.main.async {
                guard let self, self.infos.isEmpty else {
                    return
                }
                self.infos = MarketInfo.infos(market: market)
                self.collectionView.reloadData()
            }
        }
        reloadMarketsFromLocal(overwrites: false)
        reloadGlobalMarketFromRemote()
        startReloadingMarketsFromRemote()
        syncWatchlistFromRemote()
    }
    
    private func reloadGlobalMarketFromRemote() {
        RouteAPI.globalMarket { [weak self] result in
            switch result {
            case let .success(market):
                DispatchQueue.global().async {
                    PropertiesDAO.shared.set(market, forKey: .globalMarket)
                }
                if let self {
                    self.infos = MarketInfo.infos(market: market)
                    self.collectionView.reloadData()
                }
            case let .failure(error):
                Logger.general.debug(category: "Web3Market", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadGlobalMarketFromRemote()
                }
            }
        }
    }
    
    private func syncWatchlistFromRemote() {
        RouteAPI.markets(category: .favorite, queue: .global()) { [weak self] result in
            switch result {
            case let .success(markets):
                let now = Date().toUTCString()
                let favoredMarkets = markets.map { market in
                    FavoredMarket(coinID: market.coinID, isFavored: true, createdAt: now)
                }
                MarketDAO.shared.saveFavoredMarkets(favoredMarkets)
            case let .failure(error):
                Logger.general.debug(category: "Web3Market", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.syncWatchlistFromRemote()
                }
            }
        }
    }
    
    private func reloadMarketsFromLocal(overwrites: Bool) {
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
    
    private func startReloadingMarketsFromRemote() {
        let reloadingDate = Self.lastReloadingDate.addingTimeInterval(refreshInterval)
        let interval = reloadingDate.timeIntervalSinceNow
        if interval <= 0 {
            reloadMarketsFromRemote()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.reloadMarketsFromRemote()
            }
        }
    }
    
    private func reloadMarketsFromRemote() {
        timer?.invalidate()
        RouteAPI.markets(category: .all, queue: .global()) { [weak self] result in
            switch result {
            case let .success(markets):
                MarketDAO.shared.save(markets: markets) {
                    self?.reloadMarketsFromLocal(overwrites: true)
                }
            case let .failure(error):
                Logger.general.debug(category: "Web3Market", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadGlobalMarketFromRemote()
                }
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
            if let favoriteMarkets {
                if favoriteMarkets.isEmpty {
                    Section.allCases.count
                } else {
                    Section.allCases.count - 1
                }
            } else {
                Section.allCases.count - 2
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .info:
            infos.count
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.web3_market_info, for: indexPath)!
            let info = infos[indexPath.item]
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.web3_token_market, for: indexPath)!
            let market = markets[indexPath.item]
            cell.reloadData(market: market)
            cell.delegate = self
            return cell
        case .noFavoriteIndicator:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.watchlist_empty, for: indexPath)!
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.web3_market_header, for: indexPath)!
        view.limit = limit
        view.category = category
        view.order = order
        view.delegate = self
        return view
    }
    
}

extension ExploreMarketViewController: Web3MarketHeaderView.Delegate {
    
    func web3MarketHeaderView(_ view: Web3MarketHeaderView, didSwitchToLimit limit: Market.Limit) {
        self.limit = limit
        reloadMarketsFromLocal(overwrites: true)
    }
    
    func web3MarketHeaderView(_ view: Web3MarketHeaderView, didSwitchToCategory category: Market.Category) {
        self.category = category
        reloadMarketsFromLocal(overwrites: true)
    }
    
    func web3MarketHeaderView(_ view: Web3MarketHeaderView, didSwitchToOrdering order: Market.OrderingExpression) {
        self.order = order
        reloadMarketsFromLocal(overwrites: true)
    }
    
}

extension ExploreMarketViewController: Web3TokenMarketCell.Delegate {
    
    func web3TokenMarketCellWantsToggleFavorite(_ cell: Web3TokenMarketCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        collectionView.isUserInteractionEnabled = false
        cell.favoriteActivityIndicatorView.startAnimating()
        let market = switch category {
        case .all:
            markets[indexPath.item]
        case .favorite:
            (favoriteMarkets ?? [])[indexPath.item]
        }
        
        func updateModel(isFavorited: Bool) {
            switch category {
            case .all:
                markets[indexPath.item].isFavorite = isFavorited
            case .favorite:
                (favoriteMarkets ?? [])[indexPath.item].isFavorite = isFavorited
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
                    showAutoHiddenHud(style: .error, text: "\(error)")
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
                    showAutoHiddenHud(style: .error, text: "\(error)")
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
    
    private struct MarketInfo {
        
        let caption: String
        let primary: String?
        let secondary: String?
        let secondaryColor: UIColor?
        
        static func infos(market: GlobalMarket) -> [MarketInfo] {
            [
                MarketInfo(
                    caption: "Market Cap",
                    primary: NamedLargeNumberFormatter.string(
                        number: market.marketCap * Currency.current.decimalRate,
                        currencyPrefix: true
                    ),
                    secondary: NumberFormatter.percentage.string(
                        decimal: market.marketCapChangePercentage
                    ),
                    secondaryColor: market.marketCapChangePercentage >= 0 ? .priceRising : .priceFalling
                ),
                MarketInfo(
                    caption: "24h Volume",
                    primary: NamedLargeNumberFormatter.string(
                        number: market.volume * Currency.current.decimalRate,
                        currencyPrefix: true
                    ),
                    secondary: NumberFormatter.percentage.string(
                        decimal: market.volumeChangePercentage
                    ),
                    secondaryColor: market.volumeChangePercentage >= 0 ? .priceRising : .priceFalling
                ),
                MarketInfo(
                    caption: "Dominance",
                    primary: NumberFormatter.percentage.string(
                        decimal: market.dominancePercentage / 100
                    ),
                    secondary: market.dominance,
                    secondaryColor: R.color.text_secondary()
                ),
            ]
        }
        
    }
    
}
