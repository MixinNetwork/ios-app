import UIKit
import OrderedCollections
import MixinServices

final class TradeMixinTokenSelectorViewController: TradeTokenSelectorViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let hasStockTokens = !stockTokens.isEmpty
        let remoteTokens = self.defaultTokens
        queue.async { [recentAssetIDsKey] in
            var chainIDs: Set<String> = []
            var allTokens: [String: BalancedSwapToken] = TokenDAO.shared
                .notHiddenTokens(includesZeroBalanceItems: true, limit: nil)
                .compactMap(BalancedSwapToken.init(tokenItem:))
                .reduce(into: [:]) { results, token in
                    results[token.assetID] = token
                    if let chainID = token.chain.chainID {
                        chainIDs.insert(chainID)
                    }
                }
            for remoteToken in remoteTokens {
                allTokens[remoteToken.assetID] = remoteToken
                if let chainID = remoteToken.chain.chainID {
                    chainIDs.insert(chainID)
                }
            }
            let tokens = allTokens.values.sorted(
                using: TokenComparator<BalancedSwapToken>(keyword: nil)
            )
            
            var groups = Group.mixinChains(ids: chainIDs)
            if hasStockTokens {
                groups.insert(.byCategory(.stock), at: 0)
            }
            
            let recentAssetIDs = PropertiesDAO.shared.jsonObject(
                forKey: recentAssetIDsKey,
                type: [String].self
            ) ?? []
            let recentTokens = recentAssetIDs.compactMap { id in
                allTokens[id]
            }
            let recentTokenChanges: [String: TokenChange] = MarketDAO.shared
                .priceChangePercentage24H(assetIDs: recentAssetIDs)
                .compactMapValues(TokenChange.init(change:))
            
            DispatchQueue.main.async {
                self.recentTokens = recentTokens
                self.recentTokenChanges = recentTokenChanges
                self.defaultTokens = tokens
                self.defaultGroups = groups
                self.collectionView.reloadData()
                self.reloadGroupSelection()
                self.reloadTokenSelection()
                self.collectionView.checkEmpty(
                    dataCount: tokens.count,
                    text: R.string.localizable.dont_have_assets(),
                    photo: R.image.emptyIndicator.ic_hidden_assets()!
                )
            }
        }
    }
    
    override func search(keyword: String) {
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self, queue] in
            guard !op.isCancelled else {
                return
            }
            let comparator = TokenComparator<BalancedSwapToken>(keyword: keyword)
            let localResults = TokenDAO.shared
                .search(
                    keyword: keyword,
                    includesZeroBalanceItems: true,
                    sorting: false,
                    limit: nil
                )
                .compactMap(BalancedSwapToken.init(tokenItem:))
                .sorted(using: comparator)
            let chainIDs = Set(localResults.compactMap(\.chain.chainID))
            let localResultGroups = Group.mixinChains(ids: chainIDs)
            
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.async {
                guard let self, self.trimmedKeyword == keyword else {
                    return
                }
                let groupBeforeSearch = self.selectedGroup
                self.searchResultsKeyword = keyword
                self.searchResults = localResults
                self.searchResultGroups = localResultGroups
                if let group = groupBeforeSearch, localResultGroups.contains(group) {
                    self.tokensForSelectedGroup = self.tokens(from: localResults, filteredBy: group)
                } else {
                    self.selectedGroup = nil
                    self.tokensForSelectedGroup = nil
                }
                self.collectionView.reloadData()
                self.reloadGroupSelection()
                self.reloadTokenSelection()
                
                self.searchRequest = RouteAPI.search(
                    keyword: keyword,
                    source: .mixin,
                    queue: queue,
                ) { [weak self] result in
                    switch result {
                    case .success(let remoteResults):
                        self?.reloadSearchResults(
                            keyword: keyword,
                            groupBeforeSearch: groupBeforeSearch,
                            localResults: localResults,
                            remoteResults: remoteResults,
                            comparator: comparator,
                        )
                    case .failure(.emptyResponse):
                        self?.reloadSearchResults(
                            keyword: keyword,
                            groupBeforeSearch: groupBeforeSearch,
                            localResults: localResults,
                            remoteResults: [],
                            comparator: comparator,
                        )
                    case .failure:
                        break
                    }
                }
            }
        }
        operationQueue.addOperation(op)
    }
    
    private func reloadSearchResults(
        keyword: String,
        groupBeforeSearch: Group?,
        localResults: [BalancedSwapToken],
        remoteResults: [SwapToken],
        comparator: TokenComparator<BalancedSwapToken>,
    ) {
        assert(!Thread.isMainThread)
        let mixedSearchResults: (items: [BalancedSwapToken], groups: OrderedSet<Group>)?
        if remoteResults.isEmpty {
            mixedSearchResults = nil
        } else {
            var localTokens = localResults.reduce(into: [:]) { results, token in
                results[token.assetID] = token
            }
            var hiddenAssetIDs: Set<String> = []
            
            // Tokens that exist in remote results, but not in local results
            let missingAssetIDs = remoteResults.map(\.assetID).filter { id in
                localTokens[id] == nil
            }
            if !missingAssetIDs.isEmpty {
                let missingTokens = TokenDAO.shared.tokenItems(with: missingAssetIDs)
                for token in missingTokens {
                    if token.isHidden {
                        hiddenAssetIDs.insert(token.assetID)
                    } else {
                        localTokens[token.assetID] = BalancedSwapToken(tokenItem: token)
                    }
                }
            }
            
            var hasStockTokens = false
            var allItems: [String: BalancedSwapToken] = remoteResults.reduce(into: [:]) { result, token in
                let assetID = token.assetID
                guard !hiddenAssetIDs.contains(assetID) else {
                    return
                }
                let localToken = localTokens[assetID]
                let balance = localToken?.decimalBalance ?? 0
                hasStockTokens = hasStockTokens || token.category == .stock
                result[assetID] = BalancedSwapToken(
                    token: token,
                    balance: balance,
                    usdPrice: localToken?.decimalUSDPrice ?? 0,
                    isMalicious: false,
                    level: localToken?.level ?? Reputation.Level.unknown.rawValue,
                )
            }
            for item in localResults where allItems[item.assetID] == nil {
                allItems[item.assetID] = item
            }
            let sortedAllItems = allItems.values.sorted(using: comparator)
            let chainIDs = Set(sortedAllItems.compactMap(\.chain.chainID))
            var groups = Group.mixinChains(ids: chainIDs)
            if hasStockTokens {
                groups.insert(.byCategory(.stock), at: 0)
            }
            mixedSearchResults = (sortedAllItems, groups)
        }
        DispatchQueue.main.async {
            guard self.trimmedKeyword == keyword else {
                return
            }
            if let mixedSearchResults {
                self.searchResultsKeyword = keyword
                self.searchResults = mixedSearchResults.items
                self.searchResultGroups = mixedSearchResults.groups
                if let group = self.selectedGroup ?? groupBeforeSearch,
                   mixedSearchResults.groups.contains(group)
                {
                    self.selectedGroup = group
                    self.tokensForSelectedGroup = self.tokens(
                        from: mixedSearchResults.items,
                        filteredBy: group
                    )
                } else {
                    self.selectedGroup = nil
                    self.tokensForSelectedGroup = nil
                }
                self.collectionView.reloadData()
                self.reloadGroupSelection()
                self.reloadTokenSelection()
            }
            self.searchBoxView.isBusy = false
            self.collectionView.checkEmpty(
                dataCount: self.searchResults?.count ?? 0,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
        }
    }
    
}
