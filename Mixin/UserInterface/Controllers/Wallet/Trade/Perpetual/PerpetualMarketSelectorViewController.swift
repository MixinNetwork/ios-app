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
    
    var onSelected: ((PerpetualMarketViewModel) -> Void)?
    
    private var categorySelectorSizeObserver: NSKeyValueObservation?
    private var categorySelectorController: CategorySelectorController!
    
    private var searchObserver: AnyCancellable?
    private var searchResultsKeyword: String?
    private var searchResults: [PerpetualMarketViewModel]?
    
    private var selectedCategory: DisplayCategory = .all
    private var markets: [DisplayCategory: [PerpetualMarketViewModel]] = [:]
    private var ordering: PerpsMarketDAO.Ordering?
    
    private var trimmedKeyword: String {
        (searchBoxView.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private var marketsForSelectedCategory: [PerpetualMarketViewModel] {
        markets[selectedCategory] ?? []
    }
    
    init() {
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
            R.string.localizable.vol_24h(),
            attributes: orderingAttributes
        )
        volumeOrderingButton.titleLabel?.adjustsFontForContentSizeCategory = true
        priceOrderingButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.price(),
            attributes: orderingAttributes
        )
        priceOrderingButton.titleLabel?.adjustsFontForContentSizeCategory = true
        changeOrderingButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.change_24h(),
            attributes: orderingAttributes
        )
        changeOrderingButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        marketsCollectionView.register(R.nib.perpetualMarketCell)
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
        updateOrdering(field: .change)
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
            let markets = PerpsMarketDAO.shared.availableMarkets(ordering: ordering, limit: nil)
            let viewModels = markets.compactMap(PerpetualMarketViewModel.init(market:))
            var results: [DisplayCategory: [PerpetualMarketViewModel]] = [.all: viewModels]
            for viewModel in viewModels {
                guard let marketCategory = viewModel.market.category.knownCase else {
                    continue
                }
                let displayCategory = DisplayCategory(category: marketCategory)
                if results[displayCategory] == nil {
                    results[displayCategory] = [viewModel]
                } else {
                    results[displayCategory]!.append(viewModel)
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
        let searchResults = marketsForSelectedCategory.filter { viewModel in
            let market = viewModel.market
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
    
    private func updateOrdering(field: PerpsMarketDAO.Ordering.Field) {
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
        if let ordering {
            switch ordering.field {
            case .volume:
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
        reloadData()
    }
    
    private func viewModel(at indexPath: IndexPath) -> PerpetualMarketViewModel {
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
        let viewModel = viewModel(at: indexPath)
        cell.load(viewModel: viewModel)
        return cell
    }
    
}

extension PerpetualMarketSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let token = viewModel(at: indexPath)
        onSelected?(token)
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

extension PerpetualMarketSelectorViewController {
    
    enum DisplayCategory {
        
        case all
        case crypto
        case stocks
        case indices
        case commodities
        case forex
        
        init(category: PerpetualMarket.Category) {
            switch category {
            case .crypto:
                self = .crypto
            case .stocks:
                self = .stocks
            case .indices:
                self = .indices
            case .commodities:
                self = .commodities
            case .forex:
                self = .forex
            }
        }
        
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
            .all, .crypto, .stocks, .indices, .commodities, .forex
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
            case .crypto:
                R.string.localizable.perps_category_crypto()
            case .stocks:
                R.string.localizable.perps_category_stocks()
            case .indices:
                R.string.localizable.perps_category_indices()
            case .commodities:
                R.string.localizable.perps_category_commodities()
            case .forex:
                R.string.localizable.perps_category_forex()
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
