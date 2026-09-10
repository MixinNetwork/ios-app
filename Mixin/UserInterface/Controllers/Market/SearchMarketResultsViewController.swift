import UIKit
import MixinServices

final class SearchMarketResultsViewController: UIViewController {
    
    private enum SearchCategory: Int, CaseIterable {
        case aggregated = 0
        case crypto = 1
        case perpetual = 2
    }
    
    private let queue = OperationQueue()
    private let aggregatedDisplayCount = 3
    
    private weak var collectionView: UICollectionView!
    
    private var categorySelectorCollectionView: UICollectionView!
    private var categoryController: CategoryController!
    
    private var cryptoSearchResults: [FavorableMarket] = []
    private var perpsSearchResults: [FavorablePerpetualMarket] = []
    private var lastKeyword: String?
    
    private var selectedCategory: SearchCategory {
        categoryController.selectedCategory
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        queue.maxConcurrentOperationCount = 1
        view.backgroundColor = R.color.background()
        
        let categorySelectorLayout = {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .estimated(73),
                heightDimension: .estimated(38),
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: itemSize,
                subitems: [item],
            )
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)
            let config = UICollectionViewCompositionalLayoutConfiguration()
            config.scrollDirection = .horizontal
            return UICollectionViewCompositionalLayout(
                section: section,
                configuration: config
            )
        }()
        let categorySelectorCollectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44),
            collectionViewLayout: categorySelectorLayout,
        )
        categorySelectorCollectionView.backgroundColor = R.color.background()
        categorySelectorCollectionView.showsHorizontalScrollIndicator = false
        view.addSubview(categorySelectorCollectionView)
        categorySelectorCollectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(54)
        }
        self.categorySelectorCollectionView = categorySelectorCollectionView
        
        let categoryController = CategoryController(collectionView: categorySelectorCollectionView)
        categoryController.resultsViewController = self
        categorySelectorCollectionView.register(R.nib.exploreSegmentCell)
        categorySelectorCollectionView.dataSource = categoryController
        categorySelectorCollectionView.delegate = categoryController
        self.categoryController = categoryController
        categorySelectorCollectionView.reloadData()
        categoryController.select(category: .aggregated)
        
        let sections: UICollectionViewCompositionalLayoutSectionProvider = { [weak self] sectionIndex, _ in
            guard let self else {
                return nil
            }
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(50),
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: itemSize,
                subitems: [item],
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 20
            let hasItems: Bool = switch self.selectedCategory {
            case .aggregated:
                switch sectionIndex {
                case 0:
                    !self.cryptoSearchResults.isEmpty
                case 1:
                    !self.perpsSearchResults.isEmpty
                default:
                    false
                }
            case .crypto:
                !self.cryptoSearchResults.isEmpty
            case .perpetual:
                !self.perpsSearchResults.isEmpty
            }
            if hasItems {
                switch self.selectedCategory {
                case .aggregated:
                    section.contentInsets = NSDirectionalEdgeInsets(
                        top: 0, leading: 0, bottom: 20, trailing: 0,
                    )
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .absolute(44),
                        ),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top,
                    )
                    section.boundarySupplementaryItems = [header]
                    let background = NSCollectionLayoutDecorationItem.background(
                        elementKind: TradeSectionBackgroundView.elementKind,
                    )
                    section.decorationItems = [background]
                case .crypto, .perpetual:
                    section.contentInsets = NSDirectionalEdgeInsets(
                        top: 8, leading: 0, bottom: 20, trailing: 0,
                    )
                }
            }
            return section
            
        }
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 6
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sections,
            configuration: config,
        )
        layout.register(
            TradeSectionBackgroundView.self,
            forDecorationViewOfKind: TradeSectionBackgroundView.elementKind,
        )
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.register(R.nib.marketSearchResultCell)
        collectionView.register(
            SearchMarketResultsHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SearchMarketResultsHeaderView.reuseIdentifier,
        )
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(categorySelectorCollectionView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        self.collectionView = collectionView
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    func search(keyword: String, completion: @escaping () -> Void) {
        guard keyword != lastKeyword else {
            completion()
            return
        }
        lastKeyword = keyword
        queue.cancelAllOperations()
        
        guard !keyword.isEmpty else {
            clear()
            completion()
            return
        }
        
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            Thread.sleep(forTimeInterval: 0.5)
            
            guard !op.isCancelled else {
                return
            }
            let localCrypto = MarketDAO.shared.markets(keyword: keyword, limit: nil)
            let localPerps = PerpsMarketDAO.shared.markets(keyword: keyword, limit: nil)
            DispatchQueue.main.async {
                guard let self, self.lastKeyword == keyword else {
                    return
                }
                self.cryptoSearchResults = localCrypto
                self.perpsSearchResults = localPerps
                self.collectionView.reloadData()
                self.checkEmpty()
            }
            
            guard !op.isCancelled else {
                return
            }
            RouteAPI.markets(keyword: keyword, queue: .global()) { [weak self] result in
                switch result {
                case .success(let markets):
                    MarketDAO.shared.save(markets: markets, dataSource: .other)
                    let combinedResults = MarketDAO.shared.markets(keyword: keyword, limit: nil)
                    DispatchQueue.main.async {
                        guard let self, self.lastKeyword == keyword else {
                            return
                        }
                        self.cryptoSearchResults = combinedResults
                        self.collectionView.reloadData()
                        self.checkEmpty()
                        completion()
                    }
                case .failure:
                    DispatchQueue.main.async {
                        guard let self, self.lastKeyword == keyword else {
                            return
                        }
                        completion()
                    }
                }
            }
        }
        queue.addOperation(op)
    }
    
    func clear() {
        lastKeyword = nil
        queue.cancelAllOperations()
        select(category: .aggregated)
        cryptoSearchResults = []
        perpsSearchResults = []
        collectionView.removeEmptyIndicator()
        collectionView.reloadData()
    }
    
    private func select(category: SearchCategory) {
        collectionView.backgroundColor = switch category {
        case .aggregated:
            R.color.background_secondary()
        case .crypto, .perpetual:
            R.color.background()
        }
        categoryController.select(category: category)
        collectionView.reloadData()
        checkEmpty()
    }
    
    private func checkEmpty() {
        guard lastKeyword != nil else {
            collectionView.removeEmptyIndicator()
            return
        }
        let count: Int
        switch selectedCategory {
        case .aggregated:
            count = cryptoSearchResults.count + perpsSearchResults.count
        case .crypto:
            count = cryptoSearchResults.count
        case .perpetual:
            count = perpsSearchResults.count
        }
        collectionView.checkEmpty(
            dataCount: count,
            text: R.string.localizable.no_results(),
            photo: R.image.emptyIndicator.ic_search_result()!,
        )
    }
    
    private final class CategoryController: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        
        weak var resultsViewController: SearchMarketResultsViewController?
        
        private(set) var selectedCategory: SearchCategory = .aggregated
        
        private let collectionView: UICollectionView
        private let categories: [SearchCategory] = SearchCategory.allCases
        
        init(collectionView: UICollectionView) {
            self.collectionView = collectionView
            super.init()
        }
        
        func select(category: SearchCategory) {
            guard let item = categories.firstIndex(of: category) else {
                return
            }
            selectedCategory = category
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
            case .aggregated:
                R.string.localizable.all()
            case .crypto:
                R.string.localizable.crypto()
            case .perpetual:
                R.string.localizable.perpetual()
            }
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
            false
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            let category = categories[indexPath.item]
            resultsViewController?.select(category: category)
        }
        
    }
    
}

extension SearchMarketResultsViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        switch selectedCategory {
        case .aggregated:
            2
        case .crypto, .perpetual:
            1
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int,
    ) -> Int {
        switch selectedCategory {
        case .aggregated:
            switch section {
            case 0:
                min(aggregatedDisplayCount, cryptoSearchResults.count)
            case 1:
                min(aggregatedDisplayCount, perpsSearchResults.count)
            default:
                0
            }
        case .crypto:
            cryptoSearchResults.count
        case .perpetual:
            perpsSearchResults.count
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath,
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: R.reuseIdentifier.market_search_result,
            for: indexPath,
        )!
        switch selectedCategory {
        case .aggregated:
            if indexPath.section == 0, indexPath.item < cryptoSearchResults.count {
                let market = cryptoSearchResults[indexPath.item]
                cell.load(market: market, subtitle: .name)
            } else if indexPath.section == 1, indexPath.item < perpsSearchResults.count {
                let market = perpsSearchResults[indexPath.item]
                cell.load(market: market)
            }
        case .crypto:
            if indexPath.item < cryptoSearchResults.count {
                let market = cryptoSearchResults[indexPath.item]
                cell.load(market: market, subtitle: .name)
            }
        case .perpetual:
            if indexPath.item < perpsSearchResults.count {
                let market = perpsSearchResults[indexPath.item]
                cell.load(market: market)
            }
        }
        return cell
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath,
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: SearchMarketResultsHeaderView.reuseIdentifier,
            for: indexPath,
        ) as! SearchMarketResultsHeaderView
        switch selectedCategory {
        case .aggregated:
            if indexPath.section == 0 {
                header.titleLabel.text = R.string.localizable.crypto()
                header.moreButton.isHidden = cryptoSearchResults.count <= aggregatedDisplayCount
                header.showMoreResults = { [weak self] in
                    self?.select(category: .crypto)
                }
            } else if indexPath.section == 1 {
                header.titleLabel.text = R.string.localizable.perpetual()
                header.moreButton.isHidden = perpsSearchResults.count <= aggregatedDisplayCount
                header.showMoreResults = { [weak self] in
                    self?.select(category: .perpetual)
                }
            }
        case .crypto, .perpetual:
            break
        }
        return header
    }
    
}

extension SearchMarketResultsViewController: UICollectionViewDelegate {
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath,
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch selectedCategory {
        case .aggregated:
            if indexPath.section == 0, indexPath.item < cryptoSearchResults.count {
                let market = cryptoSearchResults[indexPath.item]
                (parent as? SearchMarketViewController)?.viewCrypto(market)
            } else if indexPath.section == 1, indexPath.item < perpsSearchResults.count {
                let market = perpsSearchResults[indexPath.item]
                (parent as? SearchMarketViewController)?.viewPerpetual(market)
            }
        case .crypto:
            if indexPath.item < cryptoSearchResults.count {
                let market = cryptoSearchResults[indexPath.item]
                (parent as? SearchMarketViewController)?.viewCrypto(market)
            }
        case .perpetual:
            if indexPath.item < perpsSearchResults.count {
                let market = perpsSearchResults[indexPath.item]
                (parent as? SearchMarketViewController)?.viewPerpetual(market)
            }
        }
    }
    
}
