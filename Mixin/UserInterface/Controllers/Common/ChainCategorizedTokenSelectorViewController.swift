import UIKit
import Combine
import OrderedCollections
import MixinServices

class ChainCategorizedTokenSelectorViewController<SelectableToken: Token>: TokenSelectorViewController, UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    
    private let maxNumberOfRecents = 6
    private let recentGroupHorizontalMargin: CGFloat = 20
    private let searchDebounceInterval: TimeInterval
    private let selectedID: String?
    
    var recentTokens: [SelectableToken] = []
    var recentTokenChanges: [String: TokenChange] = [:] // Key is token's id
    
    var defaultTokens: [SelectableToken]
    var defaultChains: OrderedSet<Chain>
    
    var selectedChain: Chain?
    var tokenIndicesForSelectedChain: [Int]?
    
    private var searchObserver: AnyCancellable?
    var searchResultsKeyword: String?
    var searchResults: [SelectableToken]?
    var searchResultChains: OrderedSet<Chain>?
    
    init(
        defaultTokens: [SelectableToken],
        defaultChains: OrderedSet<Chain>,
        searchDebounceInterval: TimeInterval,
        selectedID: String?
    ) {
        self.defaultTokens = defaultTokens
        self.defaultChains = defaultChains
        self.searchDebounceInterval = searchDebounceInterval
        self.selectedID = selectedID
        super.init()
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
        collectionView.register(R.nib.swapTokenCell)
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
            case .chainSelector:
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
        reloadChainSelection()
    }
    
    @objc func prepareForSearch(_ textField: UITextField) {
        let keyword = self.trimmedKeyword
        if keyword.isEmpty {
            searchResultsKeyword = nil
            searchResults = nil
            searchResultChains = nil
            if let chain = selectedChain, defaultChains.contains(chain) {
                tokenIndicesForSelectedChain = tokenIndices(tokens: defaultTokens, chainID: chain.id)
            } else {
                tokenIndicesForSelectedChain = nil
            }
            collectionView.reloadData()
            collectionView.checkEmpty(
                dataCount: defaultTokens.count,
                text: R.string.localizable.dont_have_assets(),
                photo: R.image.emptyIndicator.ic_hidden_assets()!
            )
            reloadChainSelection()
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
    
    func tokenIndices(tokens: [SelectableToken], chainID: String) -> [Int] {
        assertionFailure("Override to implement chain filter")
        return []
    }
    
    func configureRecentCell(_ cell: ExploreRecentSearchCell, withToken token: SelectableToken) {
        
    }
    
    func configureTokenCell(_ cell: SwapTokenCell, withToken token: SelectableToken) {
        
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
        case .chainSelector:
            return (searchResultChains ?? defaultChains).count + 1 // 1 for the "All"
        case .tokens:
            return tokenIndicesForSelectedChain?.count
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
        case .chainSelector:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            if indexPath.item == 0 {
                cell.label.text = R.string.localizable.all()
            } else {
                let chains = searchResultChains ?? defaultChains
                cell.label.text = chains[indexPath.item - 1].name
            }
            return cell
        case .tokens:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_token, for: indexPath)!
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
        case .chainSelector:
            if let indexPathsForSelectedItems = collectionView.indexPathsForSelectedItems {
                for selectedIndexPath in indexPathsForSelectedItems {
                    if selectedIndexPath.section == Section.chainSelector.rawValue && selectedIndexPath.item != indexPath.item {
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
        case .recent, .chainSelector:
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
        case .chainSelector:
            if indexPath.item == 0 {
                selectedChain = nil
                tokenIndicesForSelectedChain = nil
            } else {
                let chainIndex = indexPath.item - 1
                if let searchResultChains, let searchResults {
                    let chain = searchResultChains[chainIndex]
                    selectedChain = chain
                    tokenIndicesForSelectedChain = tokenIndices(tokens: searchResults, chainID: chain.id)
                } else {
                    let chain = defaultChains[chainIndex]
                    selectedChain = chain
                    tokenIndicesForSelectedChain = tokenIndices(tokens: defaultTokens, chainID: chain.id)
                }
            }
            self.reloadWithoutAnimation(section: .tokens)
            self.reloadTokenSelection()
        case .tokens:
            let token = token(at: indexPath)
            if searchResults == nil {
                if selectedChain == nil {
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
        case chainSelector
        case tokens
    }
    
    enum PickUpLocation {
        
        case recent
        case allItems
        case chainFilteredItems
        case searchResults
        
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
            }
        }
        
    }
    
    struct Chain: Equatable, Hashable {
        
        let id: String
        let name: String
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        static func mixinChains(ids: Set<String>) -> OrderedSet<Chain> {
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
            let chains = all.filter { chain in
                ids.contains(chain.id)
            }
            return OrderedSet(chains)
        }
        
        static func web3Chains(ids: Set<String>) -> OrderedSet<Chain> {
            let chains = Web3Chain.all.filter { chain in
                ids.contains(chain.chainID)
            }.map { chain in
                Chain(id: chain.chainID, name: chain.name)
            }
            return OrderedSet(chains)
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
    
    func reloadChainSelection() {
        let chains = searchResultChains ?? defaultChains
        let item = if let chain = selectedChain, let index = chains.firstIndex(of: chain) {
            index + 1 // 1 for the "All"
        } else {
            0
        }
        let indexPath = IndexPath(item: item, section: Section.chainSelector.rawValue)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    func reloadTokenSelection() {
        guard let id = selectedID else {
            return
        }
        let item: Int
        if let searchResults {
            if let index = searchResults.firstIndex(where: { $0.assetID == id }) {
                if let indices = tokenIndicesForSelectedChain {
                    if let i = indices.firstIndex(of: index) {
                        item = i
                    } else {
                        // The selected token doesn't match with selected chain
                        return
                    }
                } else {
                    item = index
                }
            } else {
                // The selected token doesn't exists in search results
                return
            }
        } else if let index = defaultTokens.firstIndex(where: { $0.assetID == id }) {
            if let indices = tokenIndicesForSelectedChain {
                if let i = indices.firstIndex(of: index) {
                    item = i
                } else {
                    // The selected token doesn't match with selected chain
                    return
                }
            } else {
                item = index
            }
        } else {
            // The selected token comes from the search results
            return
        }
        let indexPath = IndexPath(item: item, section: Section.tokens.rawValue)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    private func token(at indexPath: IndexPath) -> SelectableToken {
        assert(indexPath.section == Section.tokens.rawValue)
        let index = if let indices = tokenIndicesForSelectedChain {
            indices[indexPath.item]
        } else {
            indexPath.item
        }
        return if let searchResults {
            searchResults[index]
        } else {
            defaultTokens[index]
        }
    }
    
    private func reloadWithoutAnimation(section: Section) {
        let sections = IndexSet(integer: section.rawValue)
        UIView.performWithoutAnimation {
            collectionView.reloadSections(sections)
        }
    }
    
}
