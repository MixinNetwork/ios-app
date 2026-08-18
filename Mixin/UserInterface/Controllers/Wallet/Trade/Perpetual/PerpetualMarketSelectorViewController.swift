import UIKit
import Combine
import MixinServices

final class PerpetualMarketSelectorViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var categorySelectorCollectionView: UICollectionView!
    @IBOutlet weak var categorySelectorLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var categorySelectorHeightConstraint: NSLayoutConstraint!
    
    var onSelected: ((FavorablePerpetualMarket) -> Void)?
    
    private var categorySelectorController: CategorySelectorController!
    
    private var searchObserver: AnyCancellable?
    private var searchResultsKeyword: String?
    private var searchResults: [FavorablePerpetualMarket]?
    
    private var selectedCategory: DisplayCategory
    private var markets: [DisplayCategory: [FavorablePerpetualMarket]] = [:]
    private var ordering: MarketOrdering
    private var displayFavoritesAsRecommendations = false
    private var isUpdatingFavorites = false
    
    private weak var marketsCollectionView: UICollectionView!
    private weak var addToWatchlistButton: UIButton?
    
    private var trimmedKeyword: String {
        (searchBoxView.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private var marketsForSelectedCategory: [FavorablePerpetualMarket] {
        markets[selectedCategory] ?? []
    }
    
    private var isShowingRecommendations: Bool {
        searchResults == nil
        && selectedCategory == .favorite
        && displayFavoritesAsRecommendations
    }
    
    init(selectedCategory: DisplayCategory, ordering: MarketOrdering?) {
        self.selectedCategory = selectedCategory
        self.ordering = ordering ?? MarketOrdering(field: .volume, direction: .descending)
        let nib = R.nib.perpetualMarketSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        searchObserver?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.rightViewMode = .always
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        searchBoxView.textField.addTarget(self, action: #selector(prepareForSearch(_:)), for: .editingChanged)
        searchBoxView.textField.delegate = self
        searchObserver = NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: searchBoxView.textField)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                let keyword = self.trimmedKeyword
                guard !keyword.isEmpty, keyword != self.searchResultsKeyword else {
                    self.searchBoxView.isBusy = false
                    return
                }
                self.search(lowercasedKeyword: keyword)
            }
        cancelButton.setTitle(R.string.localizable.cancel(), for: .normal)
        
        categorySelectorController = CategorySelectorController(
            collectionView: categorySelectorCollectionView
        )
        categorySelectorCollectionView.register(R.nib.perpsMarketSelectorCategoryCell)
        categorySelectorCollectionView.dataSource = categorySelectorController
        categorySelectorCollectionView.delegate = categorySelectorController
        categorySelectorController.delegate = self
        categorySelectorCollectionView.reloadData()
        categorySelectorController.select(category: selectedCategory)
        
        let layout = UICollectionViewCompositionalLayout { [weak self] (_, _) in
            guard let self else {
                return nil
            }
            if self.isShowingRecommendations {
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .fractionalHeight(1)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(60)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
                group.interItemSpacing = .fixed(10)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                let footer = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(82)
                    ),
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottom
                )
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.boundarySupplementaryItems = [footer]
                section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0)
                return section
            } else {
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(50)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(42)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                header.pinToVisibleBounds = true
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [header]
                section.interGroupSpacing = 20
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
                return section
            }
        }
        let marketsCollectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        view.addSubview(marketsCollectionView)
        marketsCollectionView.snp.makeConstraints { make in
            make.top.equalTo(categorySelectorCollectionView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        self.marketsCollectionView = marketsCollectionView
        marketsCollectionView.backgroundColor = R.color.background()
        marketsCollectionView.register(R.nib.favorablePerpsMarketCell)
        marketsCollectionView.register(R.nib.watchlistRecommendationItemCell)
        marketsCollectionView.register(R.nib.marketLoadingCell)
        marketsCollectionView.register(
            R.nib.perpsMarketOrderingHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        marketsCollectionView.register(
            R.nib.watchlistRecommendationFooterView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter
        )
        marketsCollectionView.allowsMultipleSelection = false
        marketsCollectionView.dataSource = self
        marketsCollectionView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadDataIfAvailable(_:)),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil
        )
        reloadData()
    }
    
    @IBAction func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func prepareForSearch(_ textField: UITextField) {
        let keyword = self.trimmedKeyword
        if keyword.isEmpty {
            searchResultsKeyword = nil
            searchResults = nil
            marketsCollectionView.reloadData()
            marketsCollectionView.allowsMultipleSelection = isShowingRecommendations
            selectAllRecommendations()
            marketsCollectionView.checkEmpty(
                dataCount: markets.count,
                text: R.string.localizable.dont_have_assets(),
                photo: R.image.emptyIndicator.ic_hidden_assets()!
            )
            searchBoxView.isBusy = false
        } else if keyword != searchResultsKeyword {
            searchBoxView.isBusy = true
        }
    }
    
    @objc private func reloadDataIfAvailable(_ notification: Notification) {
        let available = !isShowingRecommendations // Do not mess up selection
            && !isUpdatingFavorites // Do not revert favorites
        if available {
            reloadData()
        }
    }
    
    private func reloadData() {
        assert(Thread.isMainThread)
        let ordering = self.ordering
        DispatchQueue.global().async { [weak self] in
            let markets = PerpsMarketDAO.shared.availableMarkets(
                ordering: ordering,
                category: nil,
                limit: nil
            )
            var results: [DisplayCategory: [FavorablePerpetualMarket]] = [
                .all: markets,
            ]
            let displayFavoritesAsRecommendations: Bool
            let favorites = markets.filter(\.isFavorite)
            if favorites.isEmpty {
                let recommendations = PerpsMarketDAO.shared.watchlistRecommendations()
                if recommendations.isEmpty {
                    results[.favorite] = []
                    displayFavoritesAsRecommendations = false
                } else {
                    results[.favorite] = recommendations
                    displayFavoritesAsRecommendations = true
                }
            } else {
                results[.favorite] = favorites
                displayFavoritesAsRecommendations = false
            }
            for market in markets {
                guard let marketCategory = market.category.knownCase else {
                    continue
                }
                let displayCategory: DisplayCategory = .categorized(marketCategory)
                if results[displayCategory] == nil {
                    results[displayCategory] = [market]
                } else {
                    results[displayCategory]!.append(market)
                }
            }
            DispatchQueue.main.async {
                guard let self, self.ordering == ordering else {
                    return
                }
                self.markets = results
                self.displayFavoritesAsRecommendations = displayFavoritesAsRecommendations
                UIView.performWithoutAnimation {
                    if let keyword = self.searchResultsKeyword {
                        self.search(lowercasedKeyword: keyword)
                    } else {
                        self.marketsCollectionView.reloadData()
                        self.marketsCollectionView.allowsMultipleSelection = self.isShowingRecommendations
                        self.marketsCollectionView.checkEmpty(
                            dataCount: self.marketsForSelectedCategory.count,
                            text: R.string.localizable.no_results(),
                            photo: R.image.emptyIndicator.ic_search_result()!
                        )
                    }
                }
            }
        }
    }
    
    private func search(lowercasedKeyword: String) {
        let searchResults = marketsForSelectedCategory.filter { market in
            let symbolMatches = market.tokenSymbol
                .lowercased()
                .contains(lowercasedKeyword)
            let tagMatches = market.tags.contains { tag in
                tag.contains(lowercasedKeyword)
            }
            return symbolMatches || tagMatches
        }
        self.searchResultsKeyword = lowercasedKeyword
        self.searchResults = searchResults
        marketsCollectionView.reloadData()
        marketsCollectionView.allowsMultipleSelection = false
        marketsCollectionView.checkEmpty(
            dataCount: searchResults.count,
            text: R.string.localizable.no_results(),
            photo: R.image.emptyIndicator.ic_search_result()!
        )
        searchBoxView.isBusy = false
    }
    
    private func market(at indexPath: IndexPath) -> FavorablePerpetualMarket {
        if let searchResults {
            searchResults[indexPath.item]
        } else {
            marketsForSelectedCategory[indexPath.item]
        }
    }
    
    private func selectAllRecommendations() {
        guard isShowingRecommendations, let favorites = markets[.favorite] else {
            return
        }
        let indexPaths = (0..<favorites.count).map { item in
            IndexPath(item: item, section: 0)
        }
        for indexPath in indexPaths {
            marketsCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }
    
    private func lockForFavoriteUpdate() {
        marketsCollectionView.isUserInteractionEnabled = false
        isUpdatingFavorites = true
    }
    
    private func unlockForFavoriteUpdate() {
        marketsCollectionView.isUserInteractionEnabled = true
        isUpdatingFavorites = false
    }
    
}

extension PerpetualMarketSelectorViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension PerpetualMarketSelectorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        searchResults?.count ?? marketsForSelectedCategory.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let market = market(at: indexPath)
        if isShowingRecommendations {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.watchlist_recommendation_item, for: indexPath)!
            cell.loadPerps(market: market)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.favorable_perps_market, for: indexPath)!
            cell.reloadData(market: market, tag: .leverage)
            cell.delegate = self
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: R.reuseIdentifier.perps_market_ordering_header,
                for: indexPath
            )!
            header.order = ordering
            header.delegate = self
            return header
        default:
            let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: R.reuseIdentifier.watchlist_recommendation_action,
                for: indexPath
            )!
            footer.delegate = self
            self.addToWatchlistButton = footer.actionButton
            return footer
        }
    }
    
}

extension PerpetualMarketSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isShowingRecommendations {
            addToWatchlistButton?.isEnabled = !(collectionView.indexPathsForSelectedItems?.isEmpty ?? true)
        } else {
            let market = market(at: indexPath)
            onSelected?(market)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        addToWatchlistButton?.isEnabled = !(collectionView.indexPathsForSelectedItems?.isEmpty ?? true)
    }
    
}

extension PerpetualMarketSelectorViewController: PerpetualMarketSelectorViewController.CategorySelectorControllerDelegate {
    
    func categorySelectorController(
        _ controller: CategorySelectorController,
        didSelectCategory category: DisplayCategory
    ) {
        self.selectedCategory = category
        if let searchResultsKeyword {
            search(lowercasedKeyword: searchResultsKeyword)
        } else {
            marketsCollectionView.reloadData()
            marketsCollectionView.allowsMultipleSelection = isShowingRecommendations
            selectAllRecommendations()
            marketsCollectionView.checkEmpty(
                dataCount: marketsForSelectedCategory.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
        }
    }
    
}

extension PerpetualMarketSelectorViewController: PerpsMarketOrderingHeaderView.Delegate {
    
    func perpsMarketOrderingHeaderView(_ view: PerpsMarketOrderingHeaderView, didSwitchToOrdering order: MarketOrdering) {
        self.ordering = order
        reloadData()
    }
    
}

extension PerpetualMarketSelectorViewController: FavorablePerpsMarketCell.Delegate {
    
    func favorablePerpsMarketCellWantsToggleFavorite(_ cell: FavorablePerpsMarketCell) {
        guard let indexPath = marketsCollectionView.indexPath(for: cell) else {
            return
        }
        lockForFavoriteUpdate()
        let market = market(at: indexPath)
        if market.isFavorite {
            cell.favoriteButton.setFavorite(false, animated: true)
            RouteAPI.unfavoritePerpsMarket(marketID: market.marketID) { [weak self] result in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        PerpsMarketDAO.shared.unfavorite(marketIDs: [market.marketID]) {
                            self?.unlockForFavoriteUpdate()
                        }
                    }
                    market.isFavorite = false
                    if let self,
                       self.selectedCategory != .favorite,
                       let all = self.markets[.all]
                    {
                        self.markets[.favorite] = all.filter(\.isFavorite)
                    }
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.watchlist_remove_desc(market.displaySymbol))
                case .failure(let error):
                    cell.favoriteButton.setFavorite(true, animated: false)
                    self?.unlockForFavoriteUpdate()
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
            reporter.report(
                event: .marketWatchlistRemove,
                tags: ["type": "perps", "source": "perps_markets_dialog"]
            )
        } else {
            cell.favoriteButton.setFavorite(true, animated: true)
            RouteAPI.favoritePerpsMarket(marketID: market.marketID) { [weak self] result in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        PerpsMarketDAO.shared.favorite(marketIDs: [market.marketID]) {
                            self?.unlockForFavoriteUpdate()
                        }
                    }
                    market.isFavorite = true
                    if let self,
                       self.selectedCategory != .favorite,
                       let all = self.markets[.all]
                    {
                        self.markets[.favorite] = all.filter(\.isFavorite)
                    }
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.watchlist_add_desc(market.displaySymbol))
                case .failure(let error):
                    cell.favoriteButton.setFavorite(false, animated: false)
                    self?.unlockForFavoriteUpdate()
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
            reporter.report(
                event: .marketWatchlistAdd,
                tags: ["type": "perps", "source": "perps_markets_dialog"]
            )
        }
    }
    
}

extension PerpetualMarketSelectorViewController: WatchlistRecommendationFooterView.Delegate {
    
    func watchlistRecommendationFooterViewDidInvokeAction(_ footerView: WatchlistRecommendationFooterView) {
        guard
            let indexPaths = marketsCollectionView.indexPathsForSelectedItems,
            !indexPaths.isEmpty,
            let favorites = markets[.favorite]
        else {
            return
        }
        let selectedMarketIDs = indexPaths.map { indexPath in
            favorites[indexPath.item].marketID
        }
        guard !selectedMarketIDs.isEmpty else {
            return
        }
        marketsCollectionView.isUserInteractionEnabled = false
        footerView.actionButton.isBusy = true
        RouteAPI.favoritePerpsMarkets(marketIDs: selectedMarketIDs) { [weak self] result in
            footerView.actionButton.isBusy = false
            switch result {
            case .success:
                DispatchQueue.global().async {
                    PerpsMarketDAO.shared.favorite(marketIDs: selectedMarketIDs) {
                        guard let self else {
                            return
                        }
                        self.marketsCollectionView.isUserInteractionEnabled = true
                        self.reloadData()
                    }
                }
            case .failure(let error):
                if let self {
                    self.marketsCollectionView.isUserInteractionEnabled = true
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
        reporter.report(
            event: .marketWatchlistAdd,
            tags: ["type": "perps", "source": "perps_markets_dialog"]
        )
    }
    
}

extension PerpetualMarketSelectorViewController {
    
    enum DisplayCategory: Hashable {
        case all
        case favorite
        case categorized(PerpetualMarket.Category)
    }
    
    protocol CategorySelectorControllerDelegate: AnyObject {
        func categorySelectorController(
            _ controller: CategorySelectorController,
            didSelectCategory category: DisplayCategory
        )
    }
    
    final class CategorySelectorController: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        
        weak var delegate: CategorySelectorControllerDelegate?
        
        private let collectionView: UICollectionView
        private let categories: [DisplayCategory] = [
            .all,
            .favorite,
            .categorized(.crypto),
            .categorized(.stocks),
            .categorized(.memes),
            .categorized(.indices),
            .categorized(.commodities),
            .categorized(.forex),
        ]
        
        init(collectionView: UICollectionView) {
            self.collectionView = collectionView
            super.init()
        }
        
        func select(category: DisplayCategory) {
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market_selector_category, for: indexPath)!
            let category = categories[indexPath.item]
            cell.category = switch category {
            case .all:
                    .text(R.string.localizable.perps_category_all())
            case .favorite:
                    .favorite
            case .categorized(.crypto):
                    .text(R.string.localizable.perps_category_crypto())
            case .categorized(.stocks):
                    .text(R.string.localizable.perps_category_stocks())
            case .categorized(.indices):
                    .text(R.string.localizable.perps_category_indices())
            case .categorized(.commodities):
                    .text(R.string.localizable.perps_category_commodities())
            case .categorized(.forex):
                    .text(R.string.localizable.perps_category_forex())
            case .categorized(.memes):
                    .text(R.string.localizable.perps_category_meme())
            }
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
            false
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let category = categories[indexPath.item]
            delegate?.categorySelectorController(self, didSelectCategory: category)
        }
        
    }
    
}
