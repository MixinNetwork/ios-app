import UIKit
import Combine
import OrderedCollections
import MixinServices

class ChainCategorizedTokenSelectorViewController<SelectableToken: Token>: TokenSelectorViewController, UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    
    let operationQueue = OperationQueue()
    let queue = DispatchQueue(label: "one.mixin.messenger.ChainCategorizedTokenSelector")
    let selectedID: String?
    
    var recentTokens: [SelectableToken] = []
    var recentTokenChanges: [String: TokenChange] = [:] // Key is token's id
    
    var defaultTokens: [SelectableToken]
    var defaultGroups: OrderedSet<Group>
    
    var selectedGroup: Group?
    var tokensForSelectedGroup: [SelectableToken]?
    
    var searchResultsKeyword: String?
    var searchResults: [SelectableToken]?
    var searchResultGroups: OrderedSet<Group>?
    
    private let maxNumberOfRecents = 6
    private let recentGroupHorizontalMargin: CGFloat = 20
    private let searchDebounceInterval: TimeInterval
    
    private var searchObserver: AnyCancellable?
    
    init(
        defaultTokens: [SelectableToken],
        defaultGroups: OrderedSet<Group>,
        searchDebounceInterval: TimeInterval,
        selectedID: String?
    ) {
        self.defaultTokens = defaultTokens
        self.defaultGroups = defaultGroups
        self.searchDebounceInterval = searchDebounceInterval
        self.selectedID = selectedID
        super.init()
        self.operationQueue.underlyingQueue = queue
        self.operationQueue.maxConcurrentOperationCount = 1
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        searchObserver?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self, action: #selector(prepareForSearch(_:)), for: .editingChanged)
        searchBoxView.textField.delegate = self
        searchObserver = NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: searchBoxView.textField)
            .debounce(for: .seconds(searchDebounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                let keyword = self.trimmedKeyword
                if !keyword.isEmpty && keyword != self.searchResultsKeyword {
                    self.search(keyword: keyword)
                } else {
                    self.searchBoxView.isBusy = false
                }
            }
        collectionView.register(
            R.nib.recentSearchHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(R.nib.exploreRecentSearchCell)
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.register(R.nib.tradeTokenCell)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self, recentGroupHorizontalMargin] (sectionIndex, environment) in
            switch Section(rawValue: sectionIndex)! {
            case .recent:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(99), heightDimension: .estimated(41))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(41))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: recentGroupHorizontalMargin, bottom: 0, trailing: recentGroupHorizontalMargin)
                group.interItemSpacing = .fixed(16)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 12
                if let self, self.searchResults == nil, !self.recentTokens.isEmpty {
                    // `contentInsets` behaves different on iOS 16/18, which may put the insets as spacing despite the section is empty
                    section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 10, trailing: 0)
                    section.boundarySupplementaryItems = [
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(24)),
                            elementKind: UICollectionView.elementKindSectionHeader,
                            alignment: .top
                        )
                    ]
                }
                return section
            case .groupSelector:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(38))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 16, trailing: 15)
                section.orthogonalScrollingBehavior = .continuous
                return section
            case .tokens:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 20
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
                return section
            }
        }
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        reloadGroupSelection()
    }
    
    @objc func prepareForSearch(_ textField: UITextField) {
        let keyword = self.trimmedKeyword
        if keyword.isEmpty {
            searchResultsKeyword = nil
            searchResults = nil
            searchResultGroups = nil
            if let group = selectedGroup, defaultGroups.contains(group) {
                tokensForSelectedGroup = tokens(from: defaultTokens, filteredBy: group)
            } else {
                tokensForSelectedGroup = nil
            }
            collectionView.reloadData()
            collectionView.checkEmpty(
                dataCount: defaultTokens.count,
                text: R.string.localizable.dont_have_assets(),
                photo: R.image.emptyIndicator.ic_hidden_assets()!
            )
            reloadGroupSelection()
            searchBoxView.isBusy = false
        } else if keyword != searchResultsKeyword {
            searchBoxView.isBusy = true
        }
    }
    
    func search(keyword: String) {
        
    }
    
    func reloadRecents(tokens: [SelectableToken], changes: [String: TokenChange]) {
        self.recentTokens = tokens
        self.recentTokenChanges = changes
        self.reloadWithoutAnimation(section: .recent)
    }
    
    func saveRecentsToStorage(tokens: any Sequence<SelectableToken>) {
        
    }
    
    func clearRecentsStorage() {
        
    }
    
    func tokens(from allTokens: [SelectableToken], filteredBy group: Group) -> [SelectableToken] {
        assertionFailure("Override to implement chain filter")
        return []
    }
    
    func configureRecentCell(_ cell: ExploreRecentSearchCell, withToken token: SelectableToken) {
        
    }
    
    func configureTokenCell(_ cell: TradeTokenCell, withToken token: SelectableToken) {
        
    }
    
    func pickUp(token: SelectableToken, from location: PickUpLocation) {
        var recentTokens = self.recentTokens
        DispatchQueue.global().async { [maxNumberOfRecents] in
            recentTokens.removeAll { recentToken in
                recentToken.assetID == token.assetID
            }
            recentTokens.insert(token, at: 0)
            let topRecentTokens = recentTokens.prefix(maxNumberOfRecents)
            self.saveRecentsToStorage(tokens: topRecentTokens)
        }
    }
    
    func reloadGroupSelection() {
        let groups = searchResultGroups ?? defaultGroups
        let item = if let group = selectedGroup, let index = groups.firstIndex(of: group) {
            index + 1 // 1 for the "All"
        } else {
            0
        }
        let indexPath = IndexPath(item: item, section: Section.groupSelector.rawValue)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    func reloadTokenSelection() {
        guard let id = selectedID else {
            return
        }
        let item: Int?
        if let tokens = tokensForSelectedGroup {
            item = tokens.firstIndex(where: { $0.assetID == id })
        } else if let tokens = searchResults {
            item = tokens.firstIndex(where: { $0.assetID == id })
        } else {
            item = defaultTokens.firstIndex(where: { $0.assetID == id })
        }
        guard let item else {
            return
        }
        let indexPath = IndexPath(item: item, section: Section.tokens.rawValue)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    func reloadWithoutAnimation(section: Section) {
        let sections = IndexSet(integer: section.rawValue)
        UIView.performWithoutAnimation {
            collectionView.reloadSections(sections)
        }
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    // MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .recent:
            return if searchResults == nil {
                recentTokens.count
            } else {
                0
            }
        case .groupSelector:
            return (searchResultGroups ?? defaultGroups).count + 1 // 1 for the "All"
        case .tokens:
            return tokensForSelectedGroup?.count
            ?? searchResults?.count
            ?? defaultTokens.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_recent_search, for: indexPath)!
            cell.maxCellWidth = collectionView.frame.width - recentGroupHorizontalMargin * 2
            cell.size = .medium
            let token = recentTokens[indexPath.item]
            configureRecentCell(cell, withToken: token)
            return cell
        case .groupSelector:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            if indexPath.item == 0 {
                cell.label.text = R.string.localizable.all()
            } else {
                let groups = searchResultGroups ?? defaultGroups
                cell.label.text = groups[indexPath.item - 1].displayName
            }
            return cell
        case .tokens:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_token, for: indexPath)!
            let token = token(at: indexPath)
            configureTokenCell(cell, withToken: token)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: R.reuseIdentifier.recent_search_header,
            for: indexPath
        )!
        view.label.text = R.string.localizable.recent()
        view.delegate = self
        return view
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            break
        case .groupSelector:
            if let indexPathsForSelectedItems = collectionView.indexPathsForSelectedItems {
                for selectedIndexPath in indexPathsForSelectedItems {
                    if selectedIndexPath.section == Section.groupSelector.rawValue && selectedIndexPath.item != indexPath.item {
                        collectionView.deselectItem(at: selectedIndexPath, animated: false)
                    }
                }
            }
        case .tokens:
            if let indexPathsForSelectedItems = collectionView.indexPathsForSelectedItems {
                for selectedIndexPath in indexPathsForSelectedItems {
                    if selectedIndexPath.section == Section.tokens.rawValue && selectedIndexPath.item != indexPath.item {
                        collectionView.deselectItem(at: selectedIndexPath, animated: false)
                    }
                }
            }
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .recent, .groupSelector:
            break
        case .tokens:
            presentingViewController?.dismiss(animated: true)
        }
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            let token = recentTokens[indexPath.item]
            pickUp(token: token, from: .recent)
        case .groupSelector:
            if indexPath.item == 0 {
                selectedGroup = nil
                tokensForSelectedGroup = nil
            } else {
                let groupIndex = indexPath.item - 1
                if let searchResultGroups, let searchResults {
                    let group = searchResultGroups[groupIndex]
                    selectedGroup = group
                    tokensForSelectedGroup = tokens(from: searchResults, filteredBy: group)
                } else {
                    let group = defaultGroups[groupIndex]
                    selectedGroup = group
                    tokensForSelectedGroup = tokens(from: defaultTokens, filteredBy: group)
                }
            }
            self.reloadWithoutAnimation(section: .tokens)
            self.reloadTokenSelection()
        case .tokens:
            let token = token(at: indexPath)
            if searchResults == nil {
                if selectedGroup == nil {
                    pickUp(token: token, from: .allItems)
                } else {
                    pickUp(token: token, from: .chainFilteredItems)
                }
            } else {
                pickUp(token: token, from: .searchResults)
            }
        }
    }
    
}

extension ChainCategorizedTokenSelectorViewController: RecentSearchHeaderView.Delegate {
    
    func recentSearchHeaderViewDidSendAction(_ view: RecentSearchHeaderView) {
        recentTokens = []
        reloadWithoutAnimation(section: .recent)
        clearRecentsStorage()
    }
    
}

extension ChainCategorizedTokenSelectorViewController {
    
    enum Section: Int, CaseIterable {
        case recent
        case groupSelector
        case tokens
    }
    
    enum PickUpLocation {
        
        case recent
        case allItems
        case chainFilteredItems
        case searchResults
        case stock
        
        var asEventMethod: String {
            switch self {
            case .recent:
                "recent_click"
            case .allItems:
                "all_item_click"
            case .chainFilteredItems:
                "chain_item_click"
            case .searchResults:
                "search_item_click"
            case .stock:
                "stock"
            }
        }
        
    }
    
    enum Group: Hashable {
        
        case byCategory(SwapToken.Category)
        case byChain(Chain)
        
        var displayName: String {
            switch self {
            case .byCategory(let category):
                switch category {
                case .stock:
                    R.string.localizable.stocks()
                }
            case .byChain(let chain):
                chain.name
            }
        }
        
        static func mixinChains(ids: Set<String>) -> OrderedSet<Group> {
            let all = [
                Chain(id: ChainID.ethereum, name: "Ethereum"),
                Chain(id: ChainID.solana, name: "Solana"),
                Chain(id: ChainID.bnbSmartChain, name: "BSC"),
                Chain(id: ChainID.base, name: "Base"),
                Chain(id: ChainID.polygon, name: "Polygon"),
                Chain(id: ChainID.tron, name: "TRON"),
                Chain(id: ChainID.arbitrumOne, name: "Arbitrum"),
                Chain(id: ChainID.opMainnet, name: "Optimism"),
                Chain(id: ChainID.ton, name: "TON"),
            ]
            let groups: [Group] = all.filter { chain in
                ids.contains(chain.id)
            }.map { chain in
                    .byChain(chain)
            }
            return OrderedSet(groups)
        }
        
        static func web3Chains(ids: Set<String>) -> OrderedSet<Group> {
            let groups: [Group] = Web3Chain.all.filter { chain in
                ids.contains(chain.chainID)
            }.map { chain in
                    .byChain(Chain(id: chain.chainID, name: chain.name))
            }
            return OrderedSet(groups)
        }
        
    }
    
    struct Chain: Equatable, Hashable {
        
        let id: String
        let name: String
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
    }
    
    struct TokenChange {
        
        let value: Decimal
        let description: String
        
        init?(change: String) {
            guard let value = Decimal(string: change, locale: .enUSPOSIX) else {
                return nil
            }
            guard let description = NumberFormatter.percentage.string(decimal: value / 100) else {
                return nil
            }
            self.value = value
            self.description = description
        }
        
    }
    
    private func token(at indexPath: IndexPath) -> SelectableToken {
        assert(indexPath.section == Section.tokens.rawValue)
        return if let tokensForSelectedGroup {
            tokensForSelectedGroup[indexPath.item]
        } else if let searchResults {
            searchResults[indexPath.item]
        } else {
            defaultTokens[indexPath.item]
        }
    }
    
}
