import UIKit
import Combine
import OrderedCollections
import Alamofire
import MixinServices

final class SwapTokenSelectorViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var onSelected: ((BalancedSwapToken) -> Void)?
    
    private let allChains: [Chain] = [
        Chain(id: ChainID.ethereum, name: "Ethereum"),
        Chain(id: ChainID.solana, name: "Solana"),
        Chain(id: ChainID.tron, name: "Tron"),
        Chain(id: ChainID.bnbSmartChain, name: "BSC"),
        Chain(id: ChainID.polygon, name: "Polygon"),
    ]
    
    private let tokens: OrderedDictionary<String, BalancedSwapToken> // Key is asset id
    private let chains: [Chain]
    private let selectedAssetID: String?
    private let recent: Recent
    private let maxNumberOfRecents = 6
    
    private var recentTokens: [BalancedSwapToken] = []
    private var recentTokenChanges: [String: TokenChange] = [:] // Key is asset id
    
    private var selectedChainIndex: Int?
    private var tokenIndicesForSelectedChain: [Int]?
    
    private weak var searchRequest: Request?
    private var searchObserver: AnyCancellable?
    private var searchResultsKeyword: String?
    private var searchResults: OrderedDictionary<String, BalancedSwapToken>? // Key is asset id
    
    private var trimmedKeyword: String {
        (searchBoxView.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    init(
        tokens: OrderedDictionary<String, BalancedSwapToken>,
        selectedAssetID: String?,
        recent: Recent
    ) {
        let chainIDs = Set(tokens.compactMap(\.value.chain.chainID))
        self.tokens = tokens
        self.chains = allChains.filter { (chain) in
            chainIDs.contains(chain.id)
        }
        self.selectedAssetID = selectedAssetID
        self.recent = recent
        let nib = R.nib.swapTokenSelectorView
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
        searchBoxView.textField.addTarget(self, action: #selector(prepareForSearch(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        searchObserver = NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: searchBoxView.textField)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.search()
            }
        collectionView.register(
            R.nib.recentSearchHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(R.nib.exploreRecentSearchCell)
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.register(R.nib.swapTokenCell)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, environment) in
            switch Section(rawValue: sectionIndex)! {
            case .recent:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(42))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(42))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                group.interItemSpacing = .fixed(16)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 12
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 20, trailing: 0)
                if let self, self.searchResults == nil, !self.recentTokens.isEmpty {
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
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
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
        reloadTokenSelection()
        reloadRecents()
    }
    
    @objc private func prepareForSearch(_ textField: UITextField) {
        searchRequest?.cancel()
        let keyword = self.trimmedKeyword
        if keyword.isEmpty {
            searchResults = nil
            collectionView.reloadData()
            collectionView.removeEmptyIndicator()
            reloadChainSelection()
            searchBoxView.isBusy = false
        } else if keyword != searchResultsKeyword {
            searchBoxView.isBusy = true
        }
    }
    
    private func search() {
        let keyword = self.trimmedKeyword
        guard !keyword.isEmpty, keyword != searchResultsKeyword else {
            searchBoxView.isBusy = false
            return
        }
        searchRequest = RouteAPI.search(keyword: keyword, source: .mixin, queue: .global()) { [weak self] result in
            switch result {
            case .success(let tokens):
                self?.reloadSearchResults(keyword: keyword, tokens: tokens)
            case .failure(.emptyResponse):
                self?.reloadSearchResults(keyword: keyword, tokens: [])
            case .failure(let error):
                Logger.general.debug(category: "SwapTokenSelector", message: "\(error)")
            }
        }
    }
    
}

extension SwapTokenSelectorViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .recent:
            if searchResults == nil {
                recentTokens.count
            } else {
                0
            }
        case .chainSelector:
            if searchResults == nil {
                chains.isEmpty ? 0 : chains.count + 1 // 1 for the "All"
            } else {
                0
            }
        case .tokens:
            if let searchResults {
                searchResults.count
            } else if let indices = tokenIndicesForSelectedChain {
                indices.count
            } else {
                tokens.count
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_recent_search, for: indexPath)!
            let token = recentTokens[indexPath.item]
            cell.setBadgeIcon { iconView in
                iconView.setIcon(swappableToken: token)
            }
            cell.titleLabel.text = token.symbol
            if let change = recentTokenChanges[token.assetID] {
                cell.subtitleLabel.marketColor = change.value >= 0 ? .rising : .falling
                cell.subtitleLabel.text = change.description
            } else {
                cell.subtitleLabel.textColor = R.color.text_tertiary()
                cell.subtitleLabel.text = token.name
            }
            return cell
        case .chainSelector:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            cell.label.text = if indexPath.item == 0 {
                R.string.localizable.all()
            } else {
                chains[indexPath.item - 1].name
            }
            return cell
        case .tokens:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_token, for: indexPath)!
            let token = token(at: indexPath)
            cell.iconView.setIcon(swappableToken: token)
            cell.titleLabel.text = token.name
            cell.subtitleLabel.text = token.localizedBalanceWithSymbol
            if let tag = token.chainTag {
                cell.chainLabel.text = tag
                cell.chainLabel.isHidden = false
            } else {
                cell.chainLabel.isHidden = true
            }
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
    
}

extension SwapTokenSelectorViewController: UICollectionViewDelegate {
    
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            let token = recentTokens[indexPath.item]
            pickUp(token: token)
        case .chainSelector:
            if indexPath.item == 0 {
                selectedChainIndex = nil
                tokenIndicesForSelectedChain = nil
            } else {
                let chainIndex = indexPath.item - 1
                selectedChainIndex = chainIndex
                let chainID = chains[chainIndex].id
                tokenIndicesForSelectedChain = tokens.enumerated().compactMap { (index, token) in
                    if token.value.chain.chainID == chainID {
                        index
                    } else {
                        nil
                    }
                }
            }
            self.reloadWithoutAnimation(section: .tokens)
            self.reloadTokenSelection()
        case .tokens:
            let token = token(at: indexPath)
            pickUp(token: token)
        }
    }
    
}

extension SwapTokenSelectorViewController: RecentSearchHeaderView.Delegate {
    
    func recentSearchHeaderViewDidSendAction(_ view: RecentSearchHeaderView) {
        recentTokens = []
        reloadWithoutAnimation(section: .recent)
        DispatchQueue.global().async { [recent] in
            PropertiesDAO.shared.removeValue(forKey: recent.key)
        }
    }
    
}

extension SwapTokenSelectorViewController {
    
    enum Recent {
        
        case send
        case receive
        
        fileprivate var key: PropertiesDAO.Key {
            switch self {
            case .send:
                    .mixinSwapRecentSendIDs
            case .receive:
                    .mixinSwapRecentReceiveIDs
            }
        }
        
    }
    
    private enum Section: Int, CaseIterable {
        case recent
        case chainSelector
        case tokens
    }
    
    private struct Chain {
        let id: String
        let name: String
    }
    
    private struct TokenChange {
        let value: Decimal
        let description: String
    }
    
    private func token(at indexPath: IndexPath) -> BalancedSwapToken {
        assert(indexPath.section == Section.tokens.rawValue)
        if let searchResults {
            return searchResults.values[indexPath.item]
        } else {
            let index = if let indices = tokenIndicesForSelectedChain {
                indices[indexPath.item]
            } else {
                indexPath.item
            }
            return tokens.values[index]
        }
    }
    
    private func reloadWithoutAnimation(section: Section) {
        let sections = IndexSet(integer: section.rawValue)
        UIView.performWithoutAnimation {
            collectionView.reloadSections(sections)
        }
    }
    
    private func reloadRecents() {
        DispatchQueue.global().async { [recent, tokens, weak self] in
            guard let recentIDs = PropertiesDAO.shared.jsonObject(forKey: recent.key, type: [String].self) else {
                return
            }
            let recentTokens = recentIDs.compactMap { id in
                tokens[id]
            }
            let changes = TokenDAO.shared.usdChanges(assetIDs: recentTokens.map(\.assetID))
            let recentTokenChanges: [String: TokenChange] = changes.compactMapValues { change in
                guard let value = Decimal(string: change, locale: .enUSPOSIX) else {
                    return nil
                }
                guard let description = NumberFormatter.percentage.string(decimal: value) else {
                    return nil
                }
                return TokenChange(value: value, description: description)
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.recentTokens = recentTokens
                self.recentTokenChanges = recentTokenChanges
                self.reloadWithoutAnimation(section: .recent)
            }
        }
    }
    
    private func reloadChainSelection() {
        assert(searchResults == nil)
        let item = if let selectedChainIndex {
            selectedChainIndex + 1
        } else {
            0
        }
        let indexPath = IndexPath(item: item, section: Section.chainSelector.rawValue)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    private func reloadTokenSelection() {
        guard let assetID = selectedAssetID else {
            return
        }
        let item: Int
        if let searchResults {
            if let index = searchResults.index(forKey: assetID) {
                item = index
            } else {
                // The selected token doesn't exists in search results
                return
            }
        } else if let index = tokens.index(forKey: assetID) {
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
            assertionFailure()
            return
        }
        let indexPath = IndexPath(item: item, section: Section.tokens.rawValue)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    private func reloadSearchResults(keyword: String, tokens: [SwapToken]) {
        assert(!Thread.isMainThread)
        let balancedTokens = BalancedSwapToken.fillBalance(swappableTokens: tokens)
        let searchResults: OrderedDictionary<String, BalancedSwapToken> = balancedTokens.reduce(into: [:]) { result, token in
            result[token.assetID] = token
        }
        DispatchQueue.main.async {
            guard self.trimmedKeyword == keyword else {
                return
            }
            self.searchResultsKeyword = keyword
            self.searchResults = searchResults
            self.collectionView.reloadData()
            self.collectionView.checkEmpty(
                dataCount: balancedTokens.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
            self.searchBoxView.isBusy = false
        }
    }
    
    private func pickUp(token: BalancedSwapToken) {
        DispatchQueue.global().async { [recent, maxNumberOfRecents] in
            var recentIDs: [String]
            if let ids = PropertiesDAO.shared.jsonObject(forKey: recent.key, type: [String].self) {
                recentIDs = ids
                if let index = recentIDs.firstIndex(of: token.assetID) {
                    recentIDs.remove(at: index)
                }
            } else {
                recentIDs = []
            }
            recentIDs.insert(token.assetID, at: 0)
            recentIDs = Array(recentIDs.prefix(maxNumberOfRecents))
            PropertiesDAO.shared.set(jsonObject: recentIDs, forKey: recent.key)
        }
        presentingViewController?.dismiss(animated: true)
        onSelected?(token)
    }
    
}
