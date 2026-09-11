import UIKit
import MixinServices

final class SearchMarketRecommendationViewController: UIViewController {
    
    private enum TrendingCategory: Int, CaseIterable {
        case crypto = 0
        case perpetual = 1
    }
    
    private enum RecentItem {
        case crypto(FavorableMarket)
        case perps(FavorablePerpetualMarket)
    }
    
    private enum Section {
        case recentSearches
        case trending
    }
    
    private let queue = DispatchQueue(label: "one.mixin.market.SearchMarketRecommendation")
    private let trendingItemsCount = 30
    
    private weak var collectionView: UICollectionView!
    
    private var recentSearches: [RecentItem] = []
    private var selectedTrendingCategory: TrendingCategory = .crypto
    private var trendingCryptoMarkets: [FavorableMarket] = []
    private var trendingPerpsMarkets: [FavorablePerpetualMarket] = []
    
    private var sections: [Section] {
        if recentSearches.isEmpty {
            [.trending]
        } else {
            [.recentSearches, .trending]
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self, sectionIndex < self.sections.count else {
                return nil
            }
            switch self.sections[sectionIndex] {
            case .recentSearches:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .estimated(102),
                    heightDimension: .estimated(42),
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(42),
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    subitems: [item],
                )
                group.interItemSpacing = .fixed(16)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 12)
                let section = NSCollectionLayoutSection(group: group)
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(56),
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top,
                )
                section.boundarySupplementaryItems = [header]
                section.interGroupSpacing = 12
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)
                return section
            case .trending:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(70),
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: itemSize,
                    subitems: [item],
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 8,
                    leading: 0,
                    bottom: 20,
                    trailing: 0,
                )
                section.interGroupSpacing = 20
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(57),
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top,
                )
                header.pinToVisibleBounds = true
                section.boundarySupplementaryItems = [header]
                return section
            }
        }
        let collectionView = UICollectionView(
            frame: view.bounds,
            collectionViewLayout: layout
        )
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.backgroundColor = R.color.background()
        self.collectionView = collectionView
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        
        collectionView.register(R.nib.recentMarketSearchCell)
        collectionView.register(
            R.nib.recentSearchHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
        )
        collectionView.register(
            SearchMarketCategoriesHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SearchMarketCategoriesHeaderView.reuseIdentifier,
        )
        collectionView.register(R.nib.marketSearchResultCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: AppGroupUserDefaults.User.recentMarketSearchesDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: MarketDAO.didUpdateNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil,
        )
        
        reloadData()
    }
    
    @objc func reloadData() {
        queue.async { [weak self, trendingItemsCount] in
            guard let self else {
                return
            }
            let recentSearches: [RecentItem] = AppGroupUserDefaults.User.recentMarketSearches.compactMap { item in
                switch item {
                case .crypto(let coinID):
                    if let market = MarketDAO.shared.market(coinID: coinID) {
                        .crypto(market)
                    } else {
                        nil
                    }
                case .perps(let marketID):
                    if let market = PerpsMarketDAO.shared.favorableMarket(marketID: marketID) {
                        .perps(market)
                    } else {
                        nil
                    }
                }
            }
            let trendingCrypto = MarketDAO.shared.markets(
                category: .trending,
                order: Market.Ordering(field: .rowid, direction: .ascending),
                limit: trendingItemsCount
            )
            let trendingPerps = PerpsMarketDAO.shared.availableMarkets(
                category: .all,
                ordering: .init(field: .score, direction: .descending),
                limit: trendingItemsCount
            )
            DispatchQueue.main.async {
                self.recentSearches = recentSearches
                self.trendingCryptoMarkets = trendingCrypto
                self.trendingPerpsMarkets = trendingPerps
                self.collectionView.reloadData()
            }
        }
    }
    
}

extension SearchMarketRecommendationViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        guard section < sections.count else {
            return 0
        }
        switch sections[section] {
        case .recentSearches:
            return recentSearches.count
        case .trending:
            switch selectedTrendingCategory {
            case .crypto:
                return trendingCryptoMarkets.count
            case .perpetual:
                return trendingPerpsMarkets.count
            }
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .recentSearches:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: R.reuseIdentifier.recent_market_search,
                for: indexPath,
            )!
            switch recentSearches[indexPath.item] {
            case .crypto(let market):
                cell.titleLabel.text = market.symbol
                cell.perpsLabel.isHidden = true
                cell.subtitleLabel.text = market.localizedPriceChangePercentage24H
                cell.subtitleLabel.marketColor = .byValue(
                    market.decimalPriceChangePercentage24H
                )
                cell.iconView.setIcon(market: market)
            case .perps(let market):
                cell.titleLabel.text = market.tokenSymbol
                cell.perpsLabel.isHidden = false
                cell.subtitleLabel.text = market.changePercentage
                cell.subtitleLabel.marketColor = .byValue(
                    market.decimalChange
                )
                cell.iconView.setIcon(urlString: market.iconURL)
            }
            return cell
        case .trending:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: R.reuseIdentifier.market_search_result,
                for: indexPath,
            )!
            switch selectedTrendingCategory {
            case .crypto:
                let market = trendingCryptoMarkets[indexPath.item]
                cell.load(market: market, subtitle: .volume)
            case .perpetual:
                let market = trendingPerpsMarkets[indexPath.item]
                cell.load(market: market)
            }
            return cell
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath,
    ) -> UICollectionReusableView {
        switch sections[indexPath.section] {
        case .recentSearches:
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: R.reuseIdentifier.recent_search_header,
                for: indexPath,
            )!
            header.delegate = self
            return header
        case .trending:
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SearchMarketCategoriesHeaderView.reuseIdentifier,
                for: indexPath,
            ) as! SearchMarketCategoriesHeaderView
            header.titles = TrendingCategory.allCases.map { category in
                switch category {
                case .crypto:
                    R.string.localizable.crypto()
                case .perpetual:
                    R.string.localizable.perpetual()
                }
            }
            header.selectButton(at: selectedTrendingCategory.rawValue)
            header.onSelect = { [weak self] index in
                guard let self, let category = TrendingCategory(rawValue: index) else {
                    return
                }
                self.selectedTrendingCategory = category
                self.collectionView.reloadData()
            }
            return header
        }
    }
    
}

extension SearchMarketRecommendationViewController: UICollectionViewDelegate {
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath,
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .recentSearches:
            switch recentSearches[indexPath.item] {
            case .crypto(let market):
                (parent as? SearchMarketViewController)?.viewCrypto(market)
            case .perps(let market):
                (parent as? SearchMarketViewController)?.viewPerpetual(market)
            }
        case .trending:
            switch selectedTrendingCategory {
            case .crypto:
                let market = trendingCryptoMarkets[indexPath.item]
                (parent as? SearchMarketViewController)?.viewCrypto(market)
            case .perpetual:
                let market = trendingPerpsMarkets[indexPath.item]
                (parent as? SearchMarketViewController)?.viewPerpetual(market)
            }
        }
    }
    
}

extension SearchMarketRecommendationViewController: RecentSearchHeaderView.Delegate {
    
    func recentSearchHeaderViewDidSendAction(_ view: RecentSearchHeaderView) {
        AppGroupUserDefaults.User.removeAllRecentMarketSearches()
        recentSearches = []
        collectionView.reloadData()
    }
    
}
