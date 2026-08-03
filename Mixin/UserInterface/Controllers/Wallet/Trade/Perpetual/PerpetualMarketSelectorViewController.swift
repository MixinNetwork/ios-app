import UIKit
import Combine
import MixinServices

final class PerpetualMarketSelectorViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var categorySelectorCollectionView: UICollectionView!
    @IBOutlet weak var categorySelectorLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var categorySelectorHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var volumeOrderingButton: UIButton!
    @IBOutlet weak var priceOrderingButton: UIButton!
    @IBOutlet weak var changeOrderingButton: UIButton!
    
    @IBOutlet weak var marketsCollectionView: UICollectionView!
    
    var onSelected: ((FavorablePerpetualMarket) -> Void)?
    
    private var categorySelectorSizeObserver: NSKeyValueObservation?
    private var categorySelectorController: CategorySelectorController!
    
    private var searchObserver: AnyCancellable?
    private var searchResultsKeyword: String?
    private var searchResults: [FavorablePerpetualMarket]?
    
    private var selectedCategory: DisplayCategory
    private var markets: [DisplayCategory: [FavorablePerpetualMarket]] = [:]
    private var ordering: MarketOrdering?
    
    private var trimmedKeyword: String {
        (searchBoxView.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private var marketsForSelectedCategory: [FavorablePerpetualMarket] {
        markets[selectedCategory] ?? []
    }
    
    init(selectedCategory: DisplayCategory, ordering: MarketOrdering?) {
        self.selectedCategory = selectedCategory
        self.ordering = ordering
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
        
        categorySelectorLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        categorySelectorController = CategorySelectorController(
            collectionView: categorySelectorCollectionView
        )
        categorySelectorCollectionView.register(R.nib.exploreSegmentCell)
        categorySelectorCollectionView.dataSource = categorySelectorController
        categorySelectorCollectionView.delegate = categorySelectorController
        categorySelectorController.delegate = self
        categorySelectorSizeObserver = categorySelectorCollectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.categorySelectorHeightConstraint.constant = newValue.height
            self.view.layoutIfNeeded()
        }
        categorySelectorCollectionView.reloadData()
        categorySelectorController.select(category: selectedCategory)
        
        let orderingAttributes = {
            var attributes = AttributeContainer()
            attributes.font = UIFont.preferredFont(forTextStyle: .caption1)
            return attributes
        }()
        volumeOrderingButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.market_volume_short(),
            attributes: orderingAttributes
        )
        volumeOrderingButton.titleLabel?.adjustsFontForContentSizeCategory = true
        priceOrderingButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.price(),
            attributes: orderingAttributes
        )
        priceOrderingButton.titleLabel?.adjustsFontForContentSizeCategory = true
        changeOrderingButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.hours_count_short(24),
            attributes: orderingAttributes
        )
        changeOrderingButton.titleLabel?.adjustsFontForContentSizeCategory = true
        updateOrderingButtonsImage(ordering: ordering)
        
        marketsCollectionView.register(R.nib.favorablePerpsMarketCell)
        marketsCollectionView.collectionViewLayout = UICollectionViewCompositionalLayout { (_, _) in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 20
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
            return section
        }
        marketsCollectionView.allowsMultipleSelection = false
        marketsCollectionView.dataSource = self
        marketsCollectionView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil
        )
        reloadData()
    }
    
    @IBAction func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func orderByVolume(_ sender: UIButton) {
        updateOrdering(field: .volume)
    }
    
    @IBAction func orderByPrice(_ sender: UIButton) {
        updateOrdering(field: .price)
    }
    
    @IBAction func orderByChange(_ sender: UIButton) {
        updateOrdering(field: .change(period: .twentyFourHours))
    }
    
    @objc private func prepareForSearch(_ textField: UITextField) {
        let keyword = self.trimmedKeyword
        if keyword.isEmpty {
            searchResultsKeyword = nil
            searchResults = nil
            marketsCollectionView.reloadData()
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
    
    @objc private func reloadData() {
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
                .favorite: markets.filter(\.isFavorite),
            ]
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
                UIView.performWithoutAnimation {
                    if let keyword = self.searchResultsKeyword {
                        self.search(lowercasedKeyword: keyword)
                    } else {
                        self.marketsCollectionView.reloadData()
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
        marketsCollectionView.checkEmpty(
            dataCount: searchResults.count,
            text: R.string.localizable.no_results(),
            photo: R.image.emptyIndicator.ic_search_result()!
        )
        searchBoxView.isBusy = false
    }
    
    private func updateOrderingButtonsImage(ordering: MarketOrdering?) {
        if let ordering {
            switch ordering.field {
            case .marketCap, .volume:
                volumeOrderingButton.configuration?.image = switch ordering.direction {
                case .ascending:
                    R.image.order_ascending()
                case .descending:
                    R.image.order_descending()
                }
                priceOrderingButton.configuration?.image = R.image.order_none()
                changeOrderingButton.configuration?.image = R.image.order_none()
            case .price:
                volumeOrderingButton.configuration?.image = R.image.order_none()
                priceOrderingButton.configuration?.image = switch ordering.direction {
                case .ascending:
                    R.image.order_ascending()
                case .descending:
                    R.image.order_descending()
                }
                changeOrderingButton.configuration?.image = R.image.order_none()
            case .change:
                volumeOrderingButton.configuration?.image = R.image.order_none()
                priceOrderingButton.configuration?.image = R.image.order_none()
                changeOrderingButton.configuration?.image = switch ordering.direction {
                case .ascending:
                    R.image.order_ascending()
                case .descending:
                    R.image.order_descending()
                }
            }
        } else {
            volumeOrderingButton.configuration?.image = R.image.order_none()
            priceOrderingButton.configuration?.image = R.image.order_none()
            changeOrderingButton.configuration?.image = R.image.order_none()
        }
    }
    
    private func updateOrdering(field: MarketOrdering.Field) {
        ordering = if let ordering, ordering.field == field {
            switch ordering.direction {
            case .ascending:
                    .none
            case .descending:
                    .init(field: field, direction: .ascending)
            }
        } else {
            .init(field: field, direction: .descending)
        }
        updateOrderingButtonsImage(ordering: ordering)
        reloadData()
    }
    
    private func market(at indexPath: IndexPath) -> FavorablePerpetualMarket {
        if let searchResults {
            searchResults[indexPath.item]
        } else {
            marketsForSelectedCategory[indexPath.item]
        }
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.favorable_perps_market, for: indexPath)!
        let market = market(at: indexPath)
        cell.reloadData(market: market)
        cell.delegate = self
        return cell
    }
    
}

extension PerpetualMarketSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let market = market(at: indexPath)
        onSelected?(market)
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
            marketsCollectionView.checkEmpty(
                dataCount: marketsForSelectedCategory.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
        }
    }
    
}

extension PerpetualMarketSelectorViewController: FavorablePerpsMarketCell.Delegate {
    
    func favorablePerpsMarketCellWantsToggleFavorite(_ cell: FavorablePerpsMarketCell) {
        guard let indexPath = marketsCollectionView.indexPath(for: cell) else {
            return
        }
        let market = market(at: indexPath)
        marketsCollectionView.isUserInteractionEnabled = false
        cell.favoriteActivityIndicatorView.startAnimating()
        if market.isFavorite {
            RouteAPI.unfavoritePerpsMarket(marketID: market.marketID) { [weak self] result in
                cell.favoriteActivityIndicatorView.stopAnimating()
                self?.marketsCollectionView.isUserInteractionEnabled = true
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
                self?.marketsCollectionView.isUserInteractionEnabled = true
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
            .categorized(.indices)
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            let category = categories[indexPath.item]
            cell.label.text = switch category {
            case .all:
                R.string.localizable.perps_category_all()
            case .favorite:
                "☆"
            case .categorized(.crypto):
                R.string.localizable.perps_category_crypto()
            case .categorized(.stocks):
                R.string.localizable.perps_category_stocks()
            case .categorized(.indices):
                R.string.localizable.perps_category_indices()
            case .categorized(.commodities):
                R.string.localizable.perps_category_commodities()
            case .categorized(.forex):
                R.string.localizable.perps_category_forex()
            case .categorized(.memes):
                R.string.localizable.perps_category_meme()
            }
            cell.badgeView.isHidden = true
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
