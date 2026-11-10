import UIKit
import MixinServices
import OrderedCollections

final class WalletSearchResultsViewController<ModelController: WalletSearchModelController>: UIViewController, UICollectionViewDelegate {
    
    private let modelController: ModelController
    private let queue = OperationQueue()
    private let aggregatedDisplayCount = 3
    
    private weak var collectionView: UICollectionView!
    
    private var categoryController: CategoryController!
    private var dataSource: DataSource!
    private var selectedCategory: WalletSearchCategory = .all
    private var results: Results?
    private var keyword = ""
    private var searchID = UUID()
    
    init(modelController: ModelController) {
        self.modelController = modelController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        view.backgroundColor = .background
        
        let categorySelectorLayout = UICollectionViewFlowLayout()
        categorySelectorLayout.scrollDirection = .horizontal
        categorySelectorLayout.minimumInteritemSpacing = 10
        categorySelectorLayout.minimumLineSpacing = 10
        categorySelectorLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        categorySelectorLayout.sectionInset = UIEdgeInsets(top: 6, left: 20, bottom: 6, right: 20)
        let categorySelectorCollectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 52),
            collectionViewLayout: categorySelectorLayout,
        )
        categorySelectorCollectionView.backgroundColor = .background
        categorySelectorCollectionView.showsHorizontalScrollIndicator = false
        categorySelectorCollectionView.register(R.nib.modernSegmentCell)
        view.addSubview(categorySelectorCollectionView)
        categorySelectorCollectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(52)
        }
        let categoryController = CategoryController(collectionView: categorySelectorCollectionView)
        categoryController.resultsViewController = self
        categorySelectorCollectionView.dataSource = categoryController
        categorySelectorCollectionView.delegate = categoryController
        self.categoryController = categoryController
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let sectionIdentifier = self?.dataSource?.sectionIdentifier(for: sectionIndex) else {
                return nil
            }
            let height: CGFloat = switch sectionIdentifier {
            case .results:
                70
            case .marketPortal:
                72
            case .emptyIndicator:
                280
            }
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalHeight(1),
            ))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(height)
                ),
                subitems: [item],
            )
            let section = NSCollectionLayoutSection(group: group)
            section.decorationItems = [NSCollectionLayoutDecorationItem.background(
                elementKind: SectionBackgroundView.CornerRadius.none.rawValue,
            )]
            switch sectionIdentifier {
            case .results:
                section.contentInsets.bottom = 10
                if self?.selectedCategory == .all {
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .absolute(44)
                        ),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top,
                    )
                    section.boundarySupplementaryItems = [header]
                }
            case .emptyIndicator, .marketPortal:
                break
            }
            return section
        }
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = 6
        layout.configuration = configuration
        layout.register(
            SectionBackgroundView.self,
            forDecorationViewOfKind: SectionBackgroundView.CornerRadius.none.rawValue,
        )
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(categorySelectorCollectionView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        self.collectionView = collectionView
        collectionView.delegate = self
        
        let resultRegistration = UICollectionView.CellRegistration<WalletSearchResultCell, SearchResult>(
            cellNib: UINib(resource: R.nib.walletSearchResultCell)
        ) { cell, _, result in
            cell.load(result: result)
        }
        let marketsRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, keyword in
            var content = cell.defaultContentConfiguration()
            content.text = R.string.localizable.search_query_in_markets(keyword)
            content.textProperties.numberOfLines = 0
            content.textProperties.color = R.color.theme()!
            content.textProperties.font = .preferredFont(forTextStyle: .callout)
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 22, leading: 20, bottom: 22, trailing: 20)
            cell.contentConfiguration = content
            cell.accessories = [.customView(configuration: .init(
                customView: UIImageView(image: R.image.ic_accessory_disclosure()),
                placement: .trailing(),
            ))]
            cell.backgroundConfiguration = .clear()
        }
        let emptyRegistration = UICollectionView.CellRegistration<EmptyIndicatorCell, Void> { _, _, _ in }
        let dataSource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self else {
                return nil
            }
            switch item {
            case .result(let id):
                guard let result = self.result(with: id) else {
                    return nil
                }
                return collectionView.dequeueConfiguredReusableCell(
                    using: resultRegistration,
                    for: indexPath,
                    item: result,
                )
            case .emptyIndicator:
                return collectionView.dequeueConfiguredReusableCell(
                    using: emptyRegistration,
                    for: indexPath,
                    item: (),
                )
            case .marketPortal:
                return collectionView.dequeueConfiguredReusableCell(
                    using: marketsRegistration,
                    for: indexPath,
                    item: self.keyword,
                )
            }
        }
        self.dataSource = dataSource
        collectionView.register(
            SearchMarketResultsHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SearchMarketResultsHeaderView.reuseIdentifier,
        )
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self, case .results(let category) = self.dataSource.sectionIdentifier(for: indexPath.section) else {
                return nil
            }
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SearchMarketResultsHeaderView.reuseIdentifier,
                for: indexPath,
            ) as! SearchMarketResultsHeaderView
            header.titleLabel.text = category.title
            header.moreButton.isHidden = self.selectedCategory != .all
                || (self.results?[category]?.count ?? 0) <= self.aggregatedDisplayCount
            header.showMoreResults = { [weak self] in
                self?.select(category: category)
            }
            return header
        }
        applySnapshot()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !keyword.isEmpty {
            update(with: keyword)
        }
    }
    
    func update(with keyword: String) {
        loadViewIfNeeded()
        self.keyword = keyword
        queue.cancelAllOperations()
        let searchID = UUID()
        self.searchID = searchID
        results = nil
        applySnapshot()
        guard !keyword.isEmpty else {
            return
        }
        let operation = BlockOperation()
        let category = selectedCategory
        let categories = category == .all ? WalletSearchCategory.allCases.filter { $0 != .all } : [category]
        let limit = category == .all ? aggregatedDisplayCount + 1 : nil
        operation.addExecutionBlock { [weak self, weak operation, modelController] in
            guard let operation, !operation.isCancelled else {
                return
            }
            var results: Results = [:]
            for category in categories {
                guard !operation.isCancelled else {
                    return
                }
                results[category] = modelController.search(
                    keyword: keyword,
                    category: category,
                    limit: limit,
                )?.reduce(into: OrderedDictionary()) { matches, result in
                    matches[result.id] = result
                }
            }
            guard !operation.isCancelled else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.searchID == searchID else {
                    return
                }
                if category == .all {
                    self.categoryController.categories = WalletSearchCategory.allCases.filter { $0 == .all || results[$0] != nil }
                }
                self.results = results
                if !self.categoryController.categories.contains(self.selectedCategory) {
                    self.selectedCategory = .all
                }
                self.applySnapshot()
            }
        }
        queue.addOperation(operation)
    }
    
    private func select(category: WalletSearchCategory) {
        selectedCategory = category
        update(with: keyword)
        collectionView.setContentOffset(.zero, animated: false)
    }
    
    private func applySnapshot() {
        var snapshot = Snapshot()
        if !keyword.isEmpty, let results {
            for category in categoryController.categories where selectedCategory == .all || selectedCategory == category {
                guard let matches = results[category], !matches.isEmpty else {
                    continue
                }
                let section = Section.results(category)
                snapshot.appendSections([section])
                let displayCount = selectedCategory == .all ? aggregatedDisplayCount : matches.count
                snapshot.appendItems(matches.keys.prefix(displayCount).map { .result($0) }, toSection: section)
            }
            if snapshot.numberOfItems == 0 {
                snapshot.appendSections([.emptyIndicator])
                snapshot.appendItems([.emptyIndicator], toSection: .emptyIndicator)
            }
            snapshot.appendSections([.marketPortal])
            snapshot.appendItems([.marketPortal], toSection: .marketPortal)
        }
        let existingItems = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existingItems.contains($0) })
        UIView.performWithoutAnimation {
            dataSource.apply(snapshot, animatingDifferences: false)
            categoryController.reloadData(selectedCategory: selectedCategory)
            collectionView.layoutIfNeeded()
        }
    }
    
    private func result(with id: SearchResult.ID) -> SearchResult? {
        results?[id.category]?[id]
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath,
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .emptyIndicator:
            return
        case .marketPortal:
            if let tabBarController = tabBarController as? HomeTabBarController {
                tabBarController.searchMarket(keyword: keyword, animated: false)
            }
        case .result(let id):
            guard let item = result(with: id) else {
                return
            }
            if let recentSearch = item.recentSearch() {
                modelController.insertRecentSearch(recentSearch)
            }
            parent?.view.endEditing(true)
            switch item {
            case .token(let token):
                modelController.reportUserSelection(token: token)
            case let .perps(_, market):
                let controller = PerpetualMarketViewController(
                    wallet: .privacy,
                    viewModel: PerpetualMarketViewModel(market: market),
                )
                navigationController?.pushViewController(controller, animated: true)
            case let .earn(product, _):
                UIApplication.shared.homeNavigationController?.presentEarnPage(
                    additionalURLQueries: ["production": product.productionID]
                )
            case .collectible(let output):
                let inscription = InscriptionViewController(output: output)
                navigationController?.pushViewController(inscription, animated: true)
            }
        }
    }
    
}

extension WalletSearchResultsViewController {
    
    private typealias SearchResult = WalletSearchItem<ModelController.Item>
    private typealias Results = [WalletSearchCategory: OrderedDictionary<SearchResult.ID, SearchResult>]
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    private enum Section: Hashable {
        case results(WalletSearchCategory)
        case emptyIndicator
        case marketPortal
    }
    
    private enum Item: Hashable {
        case result(SearchResult.ID)
        case emptyIndicator
        case marketPortal
    }
    
    private final class EmptyIndicatorCell: UICollectionViewCell {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            let indicator = R.nib.emptyView(withOwner: nil)!
            indicator.iconImageView.image = R.image.emptyIndicator.ic_search_result()
            indicator.tipsLabel.text = R.string.localizable.no_results()
            contentView.addSubview(indicator)
            indicator.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview().offset(20)
                make.trailing.lessThanOrEqualToSuperview().offset(-20)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("Storyboard not supported")
        }
        
    }
    
    private final class CategoryController: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        
        weak var resultsViewController: WalletSearchResultsViewController?
        
        var categories: [WalletSearchCategory] = [.all, .tokens, .perps, .collectibles]
        
        private weak var collectionView: UICollectionView!
        
        init(collectionView: UICollectionView) {
            self.collectionView = collectionView
            super.init()
        }
        
        func reloadData(selectedCategory: WalletSearchCategory) {
            collectionView.reloadData()
            guard let item = categories.firstIndex(of: selectedCategory) else {
                return
            }
            collectionView.selectItem(
                at: IndexPath(item: item, section: 0),
                animated: false,
                scrollPosition: [],
            )
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            categories.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.modern_segment, for: indexPath)!
            cell.label.text = categories[indexPath.item].title
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
            false
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            guard let resultsViewController else {
                return
            }
            resultsViewController.select(category: categories[indexPath.item])
        }
        
    }
    
}
