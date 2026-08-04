import UIKit
import MixinServices

final class MarketDashboardViewController: UIViewController {
    
    private let queue = OperationQueue()
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private var categorySelectorCollectionView: UICollectionView!
    private var categorySelectorSizeObserver: NSKeyValueObservation?
    private var categoryController: CategoryController!
    private var categorySelectorHeightConstraint: NSLayoutConstraint!
    
    private var category: Category {
        didSet {
            AppGroupUserDefaults.User.marketCategory = category.rawValue
        }
    }
    private var subCategoryIndex: Int
    private var order: MarketOrdering?
    
    private var collectionView: UICollectionView!
    private var dataSource: DiffableDataSource!
    
    private var markets: [String: FavorableMarket] = [:]
    private var perpsMarkets: [String: FavorablePerpetualMarket] = [:]
    private var marketIndicator: MarketIndicator?
    private var reloadDataOnViewAppear = false
    
    private var marketLoader: MarketPeriodicRequester?
    private var perpsMarketLoader: PerpetualMarketLoader?
    
    private weak var searchViewController: UIViewController?
    private weak var searchViewCenterYConstraint: NSLayoutConstraint?
    private weak var addToWatchlistButton: UIButton?
    
    init() {
        let category: Category
        if let rawValue = AppGroupUserDefaults.User.marketCategory,
           let savedCategory = Category(rawValue: rawValue)
        {
            category = savedCategory
        } else {
            category = .crypto
        }
        let subCategoryIndex = category.defaultSubCategoryIndex
        self.category = category
        self.subCategoryIndex = subCategoryIndex
        self.order = .derived(
            category: category,
            subCategoryIndex: subCategoryIndex
        )
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
        
        let categorySelectorLayout = UICollectionViewFlowLayout()
        categorySelectorLayout.scrollDirection = .horizontal
        categorySelectorLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        categorySelectorLayout.estimatedItemSize = CGSize(width: 90, height: 38)
        categorySelectorLayout.sectionInset = UIEdgeInsets(top: 3, left: 15, bottom: 3, right: 15)
        categorySelectorLayout.minimumInteritemSpacing = 0
        categorySelectorLayout.minimumLineSpacing = 0
        let categorySelectorCollectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44),
            collectionViewLayout: categorySelectorLayout
        )
        categorySelectorCollectionView.backgroundColor = R.color.background()
        categorySelectorCollectionView.showsHorizontalScrollIndicator = false
        view.addSubview(categorySelectorCollectionView)
        categorySelectorCollectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleView.snp.bottom).offset(13)
        }
        let categorySelectorHeightConstraint = categorySelectorCollectionView.heightAnchor.constraint(equalToConstant: 44)
        categorySelectorHeightConstraint.isActive = true
        self.categorySelectorHeightConstraint = categorySelectorHeightConstraint
        categorySelectorSizeObserver = categorySelectorCollectionView.observe(
            \.contentSize,
             options: [.new]
        ) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.categorySelectorHeightConstraint.constant = newValue.height
            self.view.layoutIfNeeded()
        }
        let categoryController = CategoryController(collectionView: categorySelectorCollectionView)
        categoryController.dashboard = self
        categorySelectorCollectionView.register(R.nib.exploreSegmentCell)
        categorySelectorCollectionView.dataSource = categoryController
        categorySelectorCollectionView.delegate = categoryController
        self.categoryController = categoryController
        categorySelectorCollectionView.reloadData()
        categoryController.select(category: category)
        
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, environment) in
            guard let section = self?.dataSource.sectionIdentifier(for: sectionIndex) else {
                return nil
            }
            switch section {
            case .market, .perps:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(67)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                header.pinToVisibleBounds = true
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [header]
                section.interGroupSpacing = 20
                return section
            case .marketIndicator:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(231))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                return section
            case .busyIndicator:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(149))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                if self?.category != .indicator {
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(25)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    )
                    header.pinToVisibleBounds = true
                    section.boundarySupplementaryItems = [header]
                }
                return section
            case .recommendationItem:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
                group.interItemSpacing = .fixed(10)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(25)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                header.pinToVisibleBounds = true
                let footer = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(82)),
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottom
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0) // Adds 20pt gap below header
                section.interGroupSpacing = 10
                section.boundarySupplementaryItems = [header, footer]
                return section
            }
        }
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.register(R.nib.favorableMarketCell)
        collectionView.register(R.nib.favorablePerpsMarketCell)
        collectionView.register(R.nib.watchlistRecommendationItemCell)
        collectionView.register(R.nib.marketIndicatorCell)
        collectionView.register(R.nib.marketLoadingCell)
        collectionView.register(
            R.nib.marketHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            R.nib.marketOrderingHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            R.nib.watchlistRecommendationFooterView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter
        )
        collectionView.backgroundColor = R.color.background()
        collectionView.contentInset.bottom = 20
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(categorySelectorCollectionView.snp.bottom).offset(13)
        }
        self.collectionView = collectionView
        collectionView.delegate = self
        
        let dataSource = DiffableDataSource(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            switch item {
            case let .market(id):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.favorable_market, for: indexPath)!
                if let self, let market = self.markets[id] {
                    cell.reloadData(market: market)
                    cell.delegate = self
                }
                return cell
            case let .perps(id):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.favorable_perps_market, for: indexPath)!
                if let self, let market = self.perpsMarkets[id] {
                    cell.reloadData(market: market)
                    cell.delegate = self
                }
                return cell
            case let .recommendation(category, id):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.watchlist_recommendation_item, for: indexPath)!
                switch category {
                case .crypto:
                    if let market = self?.markets[id] {
                        cell.loadCrypto(market: market)
                    }
                case .perps:
                    if let market = self?.perpsMarkets[id] {
                        cell.loadPerps(market: market)
                    }
                }
                return cell
            case let .marketIndicator(indicator):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.market_indicator, for: indexPath)!
                cell.load(indicator: indicator)
                return cell
            case .busyIndicator:
                return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.market_loading, for: indexPath)!
            }
        }
        dataSource.supplementaryViewProvider = { [unowned dataSource, weak self] collectionView, elementKind, indexPath in
            guard let self, let section = dataSource.sectionIdentifier(for: indexPath.section) else {
                return nil
            }
            switch section {
            case .market, .perps:
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: R.reuseIdentifier.market_ordering_header,
                    for: indexPath
                )!
                switch self.category {
                case .watchlist:
                    header.subCategories = WatchlistSubCategory.allCases.map(\.displayTitle)
                    header.leftOrderButton.alpha = 0
                    switch WatchlistSubCategory.allCases[self.subCategoryIndex] {
                    case .crypto:
                        header.changePeriod = AppGroupUserDefaults.User.cryptoMarketChangePeriod
                    case .perps:
                        header.changePeriod = .twentyFourHours
                    }
                case .crypto:
                    header.subCategories = Market.SubCategory.allCases.map(\.displayTitle)
                    header.leftOrderButton.alpha = 1
                    header.leftOrderingField = Market.SubCategory.allCases[self.subCategoryIndex] == .all ? .marketCap : .volume
                    header.changePeriod = AppGroupUserDefaults.User.cryptoMarketChangePeriod
                case .perps:
                    header.subCategories = PerpetualMarket.SubCategory.allCases.map(\.displayTitle)
                    header.leftOrderButton.alpha = 1
                    header.leftOrderingField = .volume
                    header.changePeriod = .twentyFourHours
                case .indicator:
                    return nil
                }
                header.selectSubCategory(at: self.subCategoryIndex)
                header.order = self.order
                header.delegate = self
                return header
            case .recommendationItem:
                switch elementKind {
                case UICollectionView.elementKindSectionHeader:
                    let header = collectionView.dequeueReusableSupplementaryView(
                        ofKind: UICollectionView.elementKindSectionHeader,
                        withReuseIdentifier: R.reuseIdentifier.market_header,
                        for: indexPath
                    )!
                    switch self.category {
                    case .watchlist:
                        header.subCategories = WatchlistSubCategory.allCases.map(\.displayTitle)
                    case .crypto:
                        header.subCategories = Market.SubCategory.allCases.map(\.displayTitle)
                    case .perps:
                        header.subCategories = PerpetualMarket.SubCategory.allCases.map(\.displayTitle)
                    case .indicator:
                        return nil
                    }
                    header.selectSubCategory(at: self.subCategoryIndex)
                    header.delegate = self
                    return header
                case UICollectionView.elementKindSectionFooter:
                    let footer = collectionView.dequeueReusableSupplementaryView(
                        ofKind: UICollectionView.elementKindSectionFooter,
                        withReuseIdentifier: R.reuseIdentifier.watchlist_recommendation_action,
                        for: indexPath
                    )!
                    footer.delegate = self
                    self.addToWatchlistButton = footer.actionButton
                    return footer
                default:
                    return nil
                }
            case .busyIndicator:
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: R.reuseIdentifier.market_header,
                    for: indexPath
                )!
                switch self.category {
                case .watchlist:
                    header.subCategories = WatchlistSubCategory.allCases.map(\.displayTitle)
                case .crypto:
                    header.subCategories = Market.SubCategory.allCases.map(\.displayTitle)
                case .perps:
                    header.subCategories = PerpetualMarket.SubCategory.allCases.map(\.displayTitle)
                case .indicator:
                    return nil
                }
                header.selectSubCategory(at: self.subCategoryIndex)
                header.delegate = self
                return header
            case .marketIndicator:
                return nil
            }
        }
        self.dataSource = dataSource
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadDataOnDatabaseUpdate),
            name: MarketDAO.didUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadDataOnDatabaseUpdate),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMarketIndicator(_:)),
            name: PropertiesDAO.propertyDidUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMarketChangePeriod(_:)),
            name: AppGroupUserDefaults.User.marketChangePeriodDidChangeNotification,
            object: nil
        )
        reloadData(
            category: category,
            subCategoryIndex: subCategoryIndex,
            order: nil,
            scheduleRemoteLoader: true,
            debugReason: "Initial",
        )
        ConcurrentJobQueue.shared.addJob(job: ReloadGlobalMarketJob())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        marketLoader?.start()
        perpsMarketLoader?.start()
        NotificationCenter.default.removeObserver(
            self,
            name: MarketDAO.favoriteNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: MarketDAO.unfavoriteNotification,
            object: nil
        )
        if reloadDataOnViewAppear {
            reloadDataOnViewAppear = false
            reloadDataWithCurrentSettings(debugReason: "ViewAppear")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        marketLoader?.pause()
        perpsMarketLoader?.stop()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleReloadDataOnViewAppear),
            name: MarketDAO.favoriteNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleReloadDataOnViewAppear),
            name: MarketDAO.unfavoriteNotification,
            object: nil
        )
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
    
    func reloadData(
        category: Category,
        subCategoryIndex: Int,
        order: MarketOrdering?, // nil to use derived order
        scheduleRemoteLoader: Bool,
        debugReason: StaticString,
    ) {
        Logger.general.debug(category: "MarketDashboard", message: "\(debugReason): Reload \(category.rawValue), subCategory: \(subCategoryIndex), order: \(order?.debugDescription ?? "(null)"), loadFromRemote: \(scheduleRemoteLoader)")
        queue.cancelAllOperations()
        if scheduleRemoteLoader {
            marketLoader?.pause()
            marketLoader = nil
            perpsMarketLoader?.stop()
            perpsMarketLoader = nil
        }
        switch category {
        case .watchlist:
            let op = ReloadWatchlistOperation(
                subCategoryIndex: subCategoryIndex,
                order: order,
                scheduleRemoteLoader: scheduleRemoteLoader,
                viewController: self
            )
            queue.addOperation(op)
        case .crypto:
            let op = ReloadMarketsOperation(
                subCategoryIndex: subCategoryIndex,
                order: order,
                scheduleRemoteLoader: scheduleRemoteLoader,
                viewController: self,
            )
            queue.addOperation(op)
        case .perps:
            let op = ReloadPerpsMarketOperation(
                subCategoryIndex: subCategoryIndex,
                order: order,
                scheduleRemoteLoader: scheduleRemoteLoader,
                viewController: self,
            )
            queue.addOperation(op)
        case .indicator:
            self.category = .indicator
            self.subCategoryIndex = 0
            var snapshot = DataSourceSnapshot()
            if let marketIndicator {
                snapshot.appendSections([.marketIndicator])
                snapshot.appendItems([.marketIndicator(marketIndicator)], toSection: .marketIndicator)
            } else {
                snapshot.appendSections([.busyIndicator])
                snapshot.appendItems([.busyIndicator], toSection: .busyIndicator)
            }
            dataSource.applySnapshotUsingReloadData(snapshot)
            ConcurrentJobQueue.shared.addJob(job: ReloadGlobalMarketJob())
        }
    }
    
    private func reloadGlobalMarket(overwrites: Bool) {
        DispatchQueue.global().async { [weak self] in
            guard let market: GlobalMarket = PropertiesDAO.shared.value(forKey: .globalMarket) else {
                return
            }
            let indicator = MarketIndicator(market: market)
            DispatchQueue.main.async {
                guard let self, self.marketIndicator == nil || overwrites else {
                    return
                }
                self.marketIndicator = indicator
                var snapshot = self.dataSource.snapshot()
                if snapshot.sectionIdentifiers.contains(.marketIndicator) {
                    snapshot.deleteAllItems()
                    snapshot.appendItems([.marketIndicator(indicator)], toSection: .marketIndicator)
                    self.dataSource.applySnapshotUsingReloadData(snapshot)
                }
            }
        }
    }
    
    private func selectAllRecommendationItems(snapshot: DataSourceSnapshot) {
        guard snapshot.sectionIdentifiers.contains(.recommendationItem) else {
            return
        }
        let items = snapshot.itemIdentifiers(inSection: .recommendationItem)
        for item in items {
            guard let indexPath = dataSource.indexPath(for: item) else {
                continue
            }
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }
    
    private func reloadDataWithCurrentSettings(debugReason: StaticString) {
        reloadData(
            category: category,
            subCategoryIndex: subCategoryIndex,
            order: order,
            scheduleRemoteLoader: false,
            debugReason: debugReason,
        )
    }
    
}

// MARK: - Actions
extension MarketDashboardViewController {
    
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
    
    @objc private func updateMarketIndicator(_ notification: Notification) {
        guard notification.userInfo?[PropertiesDAO.Key.globalMarket] != nil else {
            return
        }
        reloadGlobalMarket(overwrites: true)
    }
    
    @objc private func reloadDataOnDatabaseUpdate(_ notification: Notification) {
        reloadDataWithCurrentSettings(debugReason: "DBUpdate")
    }
    
    @objc private func scheduleReloadDataOnViewAppear(_ notification: Notification) {
        reloadDataOnViewAppear = true
    }
    
    @objc private func updateMarketChangePeriod(_ notification: Notification) {
        if let order, case .change = order.field {
            let order = MarketOrdering(
                field: .change(period: AppGroupUserDefaults.User.cryptoMarketChangePeriod),
                direction: order.direction
            )
            reloadData(
                category: category,
                subCategoryIndex: subCategoryIndex,
                order: order,
                scheduleRemoteLoader: false,
                debugReason: "ChangePeriodUpdate",
            )
        } else {
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
            dataSource.apply(snapshot) {
                if let headerView = self.collectionView.supplementaryView(
                    forElementKind: UICollectionView.elementKindSectionHeader,
                    at: IndexPath(item: 0, section: 0)
                ) as? MarketOrderingHeaderView {
                    headerView.changePeriod = AppGroupUserDefaults.User.cryptoMarketChangePeriod
                }
            }
        }
    }
    
}

// MARK: - UICollectionViewDelegate
extension MarketDashboardViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case let .market(id):
            if let market = markets[id] {
                let controller = MarketViewController(market: market)
                controller.pushingViewController = self
                navigationController?.pushViewController(controller, animated: true)
            }
        case let .perps(id):
            if let market = perpsMarkets[id],
               let viewModel = PerpetualMarketViewModel(market: market)
            {
                let market = PerpetualMarketViewController(
                    wallet: .privacy,
                    viewModel: viewModel,
                )
                navigationController?.pushViewController(market, animated: true)
            }
        case .recommendation:
            addToWatchlistButton?.isEnabled = !(collectionView.indexPathsForSelectedItems?.isEmpty ?? true)
        case .busyIndicator, .marketIndicator:
            break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        addToWatchlistButton?.isEnabled = !(collectionView.indexPathsForSelectedItems?.isEmpty ?? true)
    }
    
}

// MARK: - MarketHeaderView.Delegate
extension MarketDashboardViewController: MarketHeaderView.Delegate {
    
    func marketHeaderView(_ view: MarketHeaderView, didSelectSubCategoryAt index: Int) {
        reloadData(
            category: category,
            subCategoryIndex: index,
            order: nil,
            scheduleRemoteLoader: true,
            debugReason: "SubCategorySwitch",
        )
        AppGroupUserDefaults.User.marketSubCategoryIndices[category.rawValue] = index
    }
    
}

// MARK: - MarketOrderingHeaderView.Delegate
extension MarketDashboardViewController: MarketOrderingHeaderView.Delegate {
    
    func marketOrderingHeaderViewDidSelectSetting(_ view: MarketOrderingHeaderView) {
        let settings: MarketDisplaySettingsViewController
        switch category {
        case .watchlist:
            switch WatchlistSubCategory.allCases[subCategoryIndex] {
            case .crypto:
                settings = MarketDisplaySettingsViewController(rows: [.quoteColor, .priceChange])
            case .perps:
                settings = MarketDisplaySettingsViewController(rows: [.quoteColor])
            }
        case .crypto:
            settings = MarketDisplaySettingsViewController(rows: [.quoteColor, .priceChange])
        case .perps:
            settings = MarketDisplaySettingsViewController(rows: [.quoteColor])
        case .indicator:
            return
        }
        present(settings, animated: true)
    }
    
    func marketOrderingHeaderView(_ view: MarketOrderingHeaderView, didSwitchToOrdering order: MarketOrdering) {
        reloadData(
            category: category,
            subCategoryIndex: subCategoryIndex,
            order: order,
            scheduleRemoteLoader: false,
            debugReason: "OrderSwitch",
        )
    }
    
}

// MARK: - FavorableMarketCell.Delegate
extension MarketDashboardViewController: FavorableMarketCell.Delegate {
    
    func favorableMarketCellWantsToggleFavorite(_ cell: FavorableMarketCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        guard case let .market(id) = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        guard let market = markets[id] else {
            return
        }
        collectionView.isUserInteractionEnabled = false
        cell.favoriteActivityIndicatorView.startAnimating()
        if market.isFavorite {
            RouteAPI.unfavoriteMarket(coinID: market.coinID) { [weak self] result in
                cell.favoriteActivityIndicatorView.stopAnimating()
                self?.collectionView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        MarketDAO.shared.unfavorite(coinIDs: [market.coinID])
                    }
                    cell.isFavorited = false
                    market.isFavorite = false
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
                        MarketDAO.shared.favorite(coinIDs: [market.coinID])
                    }
                    cell.isFavorited = true
                    market.isFavorite = true
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.watchlist_add_desc(market.symbol))
                case .failure(let error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
    }
    
}

// MARK: - FavorablePerpsMarketCell.Delegate
extension MarketDashboardViewController: FavorablePerpsMarketCell.Delegate {
    
    func favorablePerpsMarketCellWantsToggleFavorite(_ cell: FavorablePerpsMarketCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        guard case let .perps(id) = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        guard let market = perpsMarkets[id] else {
            return
        }
        collectionView.isUserInteractionEnabled = false
        cell.favoriteActivityIndicatorView.startAnimating()
        if market.isFavorite {
            RouteAPI.unfavoritePerpsMarket(marketID: market.marketID) { [weak self] result in
                cell.favoriteActivityIndicatorView.stopAnimating()
                self?.collectionView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        PerpsMarketDAO.shared.unfavorite(marketIDs: [market.marketID])
                    }
                    cell.isFavorited = false
                    market.isFavorite = false
                case .failure(let error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        } else {
            RouteAPI.favoritePerpsMarket(marketID: market.marketID) { [weak self] result in
                cell.favoriteActivityIndicatorView.stopAnimating()
                self?.collectionView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        PerpsMarketDAO.shared.favorite(marketIDs: [market.marketID])
                    }
                    cell.isFavorited = true
                    market.isFavorite = true
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.watchlist_add_desc(market.displaySymbol))
                case .failure(let error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
    }
    
}

// MARK: - WatchlistRecommendationActionCell.Delegate
extension MarketDashboardViewController: WatchlistRecommendationFooterView.Delegate {
    
    func watchlistRecommendationFooterViewDidInvokeAction(_ cell: WatchlistRecommendationFooterView) {
        guard let indexPaths = collectionView.indexPathsForSelectedItems, !indexPaths.isEmpty else {
            return
        }
        var marketCoinIDs: [String] = []
        var perpsMarketIDs: [String] = []
        for indexPath in indexPaths {
            guard let item = dataSource.itemIdentifier(for: indexPath) else {
                continue
            }
            guard case let .recommendation(category, id) = item else {
                continue
            }
            switch category {
            case .crypto:
                marketCoinIDs.append(id)
            case .perps:
                perpsMarketIDs.append(id)
            }
        }
        if !marketCoinIDs.isEmpty {
            collectionView.isUserInteractionEnabled = false
            cell.actionButton.isBusy = true
            RouteAPI.favoriteMarkets(coinIDs: marketCoinIDs) { [weak self] result in
                cell.actionButton.isBusy = false
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        MarketDAO.shared.favorite(coinIDs: marketCoinIDs) {
                            guard let self else {
                                return
                            }
                            self.collectionView.isUserInteractionEnabled = true
                            self.reloadDataWithCurrentSettings(debugReason: "ApplyRcmd")
                        }
                    }
                case .failure(let error):
                    if let self {
                        self.collectionView.isUserInteractionEnabled = true
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                }
            }
        } else if !perpsMarketIDs.isEmpty {
            collectionView.isUserInteractionEnabled = false
            cell.actionButton.isBusy = true
            RouteAPI.favoritePerpsMarkets(marketIDs: perpsMarketIDs) { [weak self] result in
                cell.actionButton.isBusy = false
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        PerpsMarketDAO.shared.favorite(marketIDs: perpsMarketIDs) {
                            guard let self else {
                                return
                            }
                            self.collectionView.isUserInteractionEnabled = true
                            self.reloadDataWithCurrentSettings(debugReason: "ApplyRcmd")
                        }
                    }
                case .failure(let error):
                    if let self {
                        self.collectionView.isUserInteractionEnabled = true
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                }
            }
        }
    }
    
}

// MARK: - MarketPeriodicRequester.Delegate
extension MarketDashboardViewController: MarketPeriodicRequester.Delegate {
    
    func marketPeriodicRequester(
        _ requester: MarketPeriodicRequester,
        didLoadMarketsIn category: Market.RequestCategory,
        markets: [Market]
    ) {
        if category == .favorite && markets.isEmpty {
            DispatchQueue.main.async(execute: requester.pause)
        }
    }
    
}

// MARK: - PerpetualMarketLoader.Delegate
extension MarketDashboardViewController: PerpetualMarketLoader.Delegate {
    
    func perpetualMarketLoader(
        _ loader: PerpetualMarketLoader,
        didLoadMultipleMarketsIn category: PerpetualMarket.RequestCategory,
        markets: [PerpetualMarket]
    ) {
        if category == .favorite && markets.isEmpty {
            DispatchQueue.main.async(execute: loader.stop)
        }
    }
    
}

extension MarketDashboardViewController {
    
    enum Category: String, CaseIterable {
        
        case watchlist
        case crypto
        case perps
        case indicator
        
        var defaultSubCategoryIndex: Int {
            let index = AppGroupUserDefaults.User.marketSubCategoryIndices[rawValue]
            return switch self {
            case .watchlist:
                if let index, index < WatchlistSubCategory.allCases.count {
                    index
                } else {
                    0
                }
            case .crypto:
                if let index, index < Market.SubCategory.allCases.count {
                    index
                } else {
                    Market.SubCategory.allCases.firstIndex(of: .trending) ?? 0
                }
            case .perps:
                if let index, index < PerpetualMarket.SubCategory.allCases.count {
                    index
                } else {
                    PerpetualMarket.SubCategory.allCases.firstIndex(of: .trending) ?? 0
                }
            case .indicator:
                0
            }
        }
        
    }
    
    enum Section {
        case market
        case perps
        case marketIndicator
        case busyIndicator
        case recommendationItem
    }
    
    enum Item: Hashable {
        case market(id: String)
        case perps(id: String)
        case busyIndicator
        case marketIndicator(MarketIndicator)
        case recommendation(subCategory: WatchlistSubCategory, id: String)
    }
    
    typealias DiffableDataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    private final class CategoryController: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        
        weak var dashboard: MarketDashboardViewController?
        
        var selectedCategory: Category? {
            if let indexPath = collectionView.indexPathsForSelectedItems?.first {
                categories[indexPath.item]
            } else {
                nil
            }
        }
        
        private let collectionView: UICollectionView
        private let categories: [Category] = Category.allCases
        
        init(collectionView: UICollectionView) {
            self.collectionView = collectionView
            super.init()
        }
        
        func select(category: Category) {
            guard let item = categories.firstIndex(of: category) else {
                return
            }
            let indexPath = IndexPath(item: item, section: 0)
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            categories.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            let category = categories[indexPath.item]
            cell.label.text = switch category {
            case .watchlist:
                R.string.localizable.watchlist()
            case .crypto:
                R.string.localizable.perps_category_crypto()
            case .perps:
                R.string.localizable.perpetual()
            case .indicator:
                R.string.localizable.indicator()
            }
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
            false
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let category = categories[indexPath.item]
            dashboard?.reloadData(
                category: category,
                subCategoryIndex: category.defaultSubCategoryIndex,
                order: nil,
                scheduleRemoteLoader: true,
                debugReason: "CategorySwitch",
            )
        }
        
    }
    
    private class ReloadDataOperation: Operation, @unchecked Sendable {
        
        weak var viewController: MarketDashboardViewController?
        
        init(
            viewController: MarketDashboardViewController,
        ) {
            self.viewController = viewController
            super.init()
        }
        
        func reloadCryptoWatchlist(
            order: MarketOrdering?,
            displayCategory: Category,
            displaySubCategoryIndex: Int,
            scheduleRemoteLoader: Bool,
        ) {
            var snapshot = DataSourceSnapshot()
            let markets = MarketDAO.shared.markets(subCategory: .watchlist, order: order)
            let showsRecommendations = markets.isEmpty
            let marketViewModels: [String: FavorableMarket]
            if showsRecommendations {
                let recommendations = MarketDAO.shared.watchlistRecommendations()
                if recommendations.isEmpty {
                    snapshot.appendSections([.busyIndicator])
                    snapshot.appendItems([.busyIndicator])
                } else {
                    snapshot.appendSections([.recommendationItem])
                    snapshot.appendItems(recommendations.map { recommendation in
                        Item.recommendation(subCategory: .crypto, id: recommendation.coinID)
                    })
                }
                marketViewModels = recommendations.reduce(into: [:]) { result, market in
                    result[market.coinID] = market
                }
            } else {
                snapshot.appendSections([.market])
                snapshot.appendItems(markets.map { market in
                    Item.market(id: market.coinID)
                })
                marketViewModels = markets.reduce(into: [:]) { result, market in
                    result[market.coinID] = market
                }
            }
            DispatchQueue.main.sync { [weak self] in
                guard let self, !self.isCancelled, let viewController else {
                    return
                }
                viewController.category = displayCategory
                viewController.subCategoryIndex = displaySubCategoryIndex
                viewController.order = order
                viewController.markets = marketViewModels
                if showsRecommendations {
                    viewController.collectionView.allowsMultipleSelection = true
                    viewController.dataSource.applySnapshotUsingReloadData(snapshot) {
                        viewController.selectAllRecommendationItems(snapshot: snapshot)
                    }
                } else {
                    viewController.collectionView.allowsMultipleSelection = false
                    viewController.dataSource.applySnapshotUsingReloadData(snapshot)
                }
                if scheduleRemoteLoader {
                    let requester = MarketPeriodicRequester(
                        category: .favorite,
                        limit: 500
                    )
                    viewController.marketLoader = requester
                    requester.delegate = viewController
                    requester.start()
                    
                    if showsRecommendations {
                        ConcurrentJobQueue.shared.addJob(
                            job: ReloadWatchlistRecommendationJob(category: .crypto)
                        )
                    }
                }
            }
        }
        
        func reloadPerpsWatchlist(
            order: MarketOrdering?,
            displayCategory: Category,
            displaySubCategoryIndex: Int,
            scheduleRemoteLoader: Bool,
        ) {
            var snapshot = DataSourceSnapshot()
            let markets = PerpsMarketDAO.shared.availableMarkets(subCategory: .watchlist, ordering: order)
            let showsRecommendations = markets.isEmpty
            let marketViewModels: [String: FavorablePerpetualMarket]
            if showsRecommendations {
                let recommendations = PerpsMarketDAO.shared.watchlistRecommendations()
                if recommendations.isEmpty {
                    snapshot.appendSections([.busyIndicator])
                    snapshot.appendItems([.busyIndicator])
                } else {
                    snapshot.appendSections([.recommendationItem])
                    snapshot.appendItems(recommendations.map { recommendation in
                        Item.recommendation(subCategory: .perps, id: recommendation.marketID)
                    })
                }
                marketViewModels = recommendations.reduce(into: [:]) { result, market in
                    result[market.marketID] = market
                }
            } else {
                snapshot.appendSections([.perps])
                snapshot.appendItems(markets.map { market in
                    Item.perps(id: market.marketID)
                })
                marketViewModels = markets.reduce(into: [:]) { result, market in
                    result[market.marketID] = market
                }
            }
            DispatchQueue.main.sync { [weak self] in
                guard let self, !self.isCancelled, let viewController else {
                    return
                }
                viewController.category = displayCategory
                viewController.subCategoryIndex = displaySubCategoryIndex
                viewController.order = order
                viewController.perpsMarkets = marketViewModels
                if showsRecommendations {
                    viewController.collectionView.allowsMultipleSelection = true
                    viewController.dataSource.applySnapshotUsingReloadData(snapshot) {
                        viewController.selectAllRecommendationItems(snapshot: snapshot)
                    }
                } else {
                    viewController.collectionView.allowsMultipleSelection = false
                    viewController.dataSource.applySnapshotUsingReloadData(snapshot)
                }
                if scheduleRemoteLoader {
                    let requester = PerpetualMarketLoader(
                        request: .multiple(.favorite),
                        timeInterval: 30
                    )
                    viewController.perpsMarketLoader = requester
                    requester.delegate = viewController
                    requester.start()
                    
                    if showsRecommendations {
                        ConcurrentJobQueue.shared.addJob(
                            job: ReloadWatchlistRecommendationJob(category: .perps)
                        )
                    }
                }
            }
        }
        
    }
    
    private class ReloadWatchlistOperation: ReloadDataOperation, @unchecked Sendable {
        
        private let subCategoryIndex: Int
        private let order: MarketOrdering?
        private let scheduleRemoteLoader: Bool
        
        init(
            subCategoryIndex: Int,
            order: MarketOrdering?,
            scheduleRemoteLoader: Bool,
            viewController: MarketDashboardViewController,
        ) {
            self.subCategoryIndex = subCategoryIndex
            self.order = order ?? .derived(
                category: .watchlist,
                subCategoryIndex: subCategoryIndex
            )
            self.scheduleRemoteLoader = scheduleRemoteLoader
            super.init(viewController: viewController)
        }
        
        override func main() {
            switch WatchlistSubCategory.allCases[subCategoryIndex] {
            case .crypto:
                reloadCryptoWatchlist(
                    order: order,
                    displayCategory: .watchlist,
                    displaySubCategoryIndex: subCategoryIndex,
                    scheduleRemoteLoader: scheduleRemoteLoader,
                )
            case .perps:
                reloadPerpsWatchlist(
                    order: order,
                    displayCategory: .watchlist,
                    displaySubCategoryIndex: subCategoryIndex,
                    scheduleRemoteLoader: scheduleRemoteLoader,
                )
            }
        }
        
    }
    
    private final class ReloadMarketsOperation: ReloadDataOperation, @unchecked Sendable {
        
        private let subCategoryIndex: Int
        private let order: MarketOrdering?
        private let scheduleRemoteLoader: Bool
        
        init(
            subCategoryIndex: Int,
            order: MarketOrdering?,
            scheduleRemoteLoader: Bool,
            viewController: MarketDashboardViewController,
        ) {
            self.subCategoryIndex = subCategoryIndex
            self.order = order ?? .derived(
                category: .crypto,
                subCategoryIndex: subCategoryIndex
            )
            self.scheduleRemoteLoader = scheduleRemoteLoader
            super.init(viewController: viewController)
        }
        
        override func main() {
            let subCategory = Market.SubCategory.allCases[subCategoryIndex]
            switch subCategory {
            case .watchlist:
                reloadCryptoWatchlist(
                    order: order,
                    displayCategory: .crypto,
                    displaySubCategoryIndex: subCategoryIndex,
                    scheduleRemoteLoader: scheduleRemoteLoader,
                )
            default:
                let markets = MarketDAO.shared.markets(subCategory: subCategory, order: order)
                let items: [Item] = markets.map { market in
                        .market(id: market.coinID)
                }
                let viewModels = markets.reduce(into: [:]) { result, market in
                    result[market.coinID] = market
                }
                var snapshot = DataSourceSnapshot()
                if items.isEmpty {
                    snapshot.appendSections([.busyIndicator])
                    snapshot.appendItems([.busyIndicator], toSection: .busyIndicator)
                } else {
                    snapshot.appendSections([.market])
                    snapshot.appendItems(items, toSection: .market)
                }
                DispatchQueue.main.sync { [weak self] in
                    guard let self, !self.isCancelled, let viewController else {
                        return
                    }
                    viewController.category = .crypto
                    viewController.subCategoryIndex = subCategoryIndex
                    viewController.order = order
                    viewController.markets = viewModels
                    viewController.collectionView.allowsMultipleSelection = false
                    viewController.dataSource.applySnapshotUsingReloadData(snapshot)
                    if scheduleRemoteLoader {
                        let requester = MarketPeriodicRequester(
                            category: Market.RequestCategory(subCategory: subCategory),
                            limit: 500
                        )
                        viewController.marketLoader = requester
                        requester.start()
                    }
                }
            }
        }
        
    }
    
    private final class ReloadPerpsMarketOperation: ReloadDataOperation, @unchecked Sendable {
        
        private let subCategoryIndex: Int
        private let order: MarketOrdering?
        private let scheduleRemoteLoader: Bool
        
        init(
            subCategoryIndex: Int,
            order: MarketOrdering?,
            scheduleRemoteLoader: Bool,
            viewController: MarketDashboardViewController,
        ) {
            self.subCategoryIndex = subCategoryIndex
            self.order = order ?? .derived(
                category: .perps,
                subCategoryIndex: subCategoryIndex
            )
            self.scheduleRemoteLoader = scheduleRemoteLoader
            super.init(viewController: viewController)
        }
        
        override func main() {
            let subCategory = PerpetualMarket.SubCategory.allCases[subCategoryIndex]
            switch subCategory {
            case .watchlist:
                reloadPerpsWatchlist(
                    order: order,
                    displayCategory: .perps,
                    displaySubCategoryIndex: subCategoryIndex,
                    scheduleRemoteLoader: scheduleRemoteLoader,
                )
            default:
                let markets = PerpsMarketDAO.shared.availableMarkets(
                    subCategory: subCategory,
                    ordering: order
                )
                let items: [Item] = markets.map { market in
                        .perps(id: market.marketID)
                }
                let viewModels = markets.reduce(into: [:]) { result, market in
                    result[market.marketID] = market
                }
                var snapshot = DataSourceSnapshot()
                if items.isEmpty {
                    snapshot.appendSections([.busyIndicator])
                    snapshot.appendItems([.busyIndicator], toSection: .busyIndicator)
                } else {
                    snapshot.appendSections([.perps])
                    snapshot.appendItems(items, toSection: .perps)
                }
                DispatchQueue.main.sync { [weak self] in
                    guard let self, !self.isCancelled, let viewController else {
                        return
                    }
                    viewController.category = .perps
                    viewController.subCategoryIndex = subCategoryIndex
                    viewController.order = order
                    viewController.perpsMarkets = viewModels
                    viewController.collectionView.allowsMultipleSelection = false
                    viewController.dataSource.applySnapshotUsingReloadData(snapshot)
                    if scheduleRemoteLoader {
                        let requester = switch subCategory {
                        case .watchlist:
                            PerpetualMarketLoader(
                                request: .multiple(.favorite),
                                timeInterval: 30
                            )
                        case .trending, .topGainers, .topLosers, .indices, .commodities, .forex, .memes:
                            PerpetualMarketLoader(
                                request: .multiple(.all),
                                timeInterval: 30
                            )
                        }
                        viewController.perpsMarketLoader = requester
                        requester.start()
                    }
                }
            }
        }
        
    }
    
}
