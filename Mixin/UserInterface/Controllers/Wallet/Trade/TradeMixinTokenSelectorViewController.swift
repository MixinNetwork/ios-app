import UIKit
import OrderedCollections
import MixinServices

final class TradeMixinTokenSelectorViewController: TradeTokenSelectorViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var remoteTokens = self.defaultTokens
        queue.async { [recentAssetIDsKey] in
            let comparator = TokenComparator<BalancedSwapToken>(keyword: nil)
            var tokens = TokenDAO.shared
                .notHiddenTokens(includesZeroBalanceItems: true)
                .compactMap(BalancedSwapToken.init(tokenItem:))
            var tokensMap = tokens.reduce(into: [:]) { results, token in
                results[token.assetID] = token
            }
            remoteTokens.removeAll { token in
                tokensMap[token.assetID] != nil
            }
            tokens.append(contentsOf: remoteTokens.sorted(using: comparator))
            for token in remoteTokens {
                tokensMap[token.assetID] = token
            }
            let chainIDs = Set(tokens.compactMap(\.chain.chainID))
            let chains = Chain.mixinChains(ids: chainIDs)
            
            let recentAssetIDs = PropertiesDAO.shared.jsonObject(
                forKey: recentAssetIDsKey,
                type: [String].self
            ) ?? []
            let recentTokens = recentAssetIDs.compactMap { id in
                tokensMap[id]
            }
            let recentTokenChanges: [String: TokenChange] = MarketDAO.shared
                .priceChangePercentage24H(assetIDs: recentAssetIDs)
                .compactMapValues(TokenChange.init(change:))
            
            DispatchQueue.main.async {
                self.recentTokens = recentTokens
                self.recentTokenChanges = recentTokenChanges
                self.defaultTokens = tokens
                self.defaultChains = chains
                self.collectionView.reloadData()
                self.reloadChainSelection()
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
            let localResultChains = Chain.mixinChains(ids: chainIDs)
            
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.async {
                guard let self, self.trimmedKeyword == keyword else {
                    return
                }
                self.searchResultsKeyword = keyword
                self.searchResults = localResults
                self.searchResultChains = localResultChains
                if let chain = self.selectedChain, chainIDs.contains(chain.id) {
                    self.tokenIndicesForSelectedChain = self.tokenIndices(tokens: localResults, chainID: chain.id)
                } else {
                    self.selectedChain = nil
                    self.tokenIndicesForSelectedChain = nil
                }
                self.collectionView.reloadData()
                self.reloadChainSelection()
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
                            localResults: localResults,
                            remoteResults: remoteResults,
                            comparator: comparator,
                        )
                    case .failure(.emptyResponse):
                        self?.reloadSearchResults(
                            keyword: keyword,
                            localResults: localResults,
                            remoteResults: [],
                            comparator: comparator,
                        )
                    case .failure(let error):
                        Logger.general.debug(category: "SwapMixinTokenSelector", message: "\(error)")
                    }
                }
            }
        }
        operationQueue.addOperation(op)
    }
    
    private func reloadSearchResults(
        keyword: String,
        localResults: [BalancedSwapToken],
        remoteResults: [SwapToken],
        comparator: TokenComparator<BalancedSwapToken>,
    ) {
        assert(!Thread.isMainThread)
        let mixedSearchResults: (items: [BalancedSwapToken], chains: OrderedSet<Chain>, chainIDs: Set<String>)?
        if remoteResults.isEmpty {
            mixedSearchResults = nil
        } else {
            let localResultsMap = localResults.reduce(into: [:]) { results, token in
                results[token.assetID] = token
            }
            var allItems: [String: BalancedSwapToken] = remoteResults.reduce(into: [:]) { result, token in
                let assetID = token.assetID
                let localResult = localResultsMap[assetID]
                let balance = localResult?.decimalBalance
                    ?? TokenExtraDAO.shared.decimalBalance(assetID: assetID)
                result[assetID] = BalancedSwapToken(
                    token: token,
                    balance: balance ?? 0,
                    usdPrice: localResult?.decimalUSDPrice ?? 0
                )
            }
            for item in localResults where allItems[item.assetID] == nil {
                allItems[item.assetID] = item
            }
            let sortedAllItems = allItems.values.sorted(using: comparator)
            let chainIDs = Set(sortedAllItems.compactMap(\.chain.chainID))
            let chains = Chain.mixinChains(ids: chainIDs)
            mixedSearchResults = (sortedAllItems, chains, chainIDs)
        }
        DispatchQueue.main.async {
            guard self.trimmedKeyword == keyword else {
                return
            }
            if let mixedSearchResults {
                self.searchResultsKeyword = keyword
                self.searchResults = mixedSearchResults.items
                self.searchResultChains = mixedSearchResults.chains
                if let chain = self.selectedChain, mixedSearchResults.chainIDs.contains(chain.id) {
                    self.tokenIndicesForSelectedChain = self.tokenIndices(
                        tokens: mixedSearchResults.items,
                        chainID: chain.id
                    )
                } else {
                    self.selectedChain = nil
                    self.tokenIndicesForSelectedChain = nil
                }
                self.collectionView.reloadData()
                self.reloadChainSelection()
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
