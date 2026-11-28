import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class TradeWeb3TokenSelectorViewController: TradeTokenSelectorViewController {
    
    private let wallet: Web3Wallet
    private let supportedChainIDs: Set<String>
    
    init(
        wallet: Web3Wallet,
        supportedChainIDs: Set<String>,
        intent: TokenSelectorIntent,
        selectedAssetID: String?,
        defaultTokens: [BalancedSwapToken],
        stockTokens: [BalancedSwapToken],
    ) {
        let supportedDefaultTokens = defaultTokens.filter { token in
            if let chainID = token.chain.chainID {
                supportedChainIDs.contains(chainID)
            } else {
                false
            }
        }
        let supportedStockTokens = stockTokens.filter { token in
            if let chainID = token.chain.chainID {
                supportedChainIDs.contains(chainID)
            } else {
                false
            }
        }
        self.wallet = wallet
        self.supportedChainIDs = supportedChainIDs
        super.init(
            intent: intent,
            selectedAssetID: selectedAssetID,
            defaultTokens: supportedDefaultTokens,
            stockTokens: supportedStockTokens,
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        operationQueue.cancelAllOperations()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let walletID = wallet.walletID
        let hasStockTokens = !stockTokens.isEmpty
        let remoteTokens = self.defaultTokens
        queue.async { [recentAssetIDsKey] in
            var chainIDs: Set<String> = []
            
            // No need to filter with `supportedChainIDs`, the `walletID` will do
            // Unsupported tokens will not exist with the `walletID`
            var allTokens: [String: BalancedSwapToken] = Web3TokenDAO.shared
                .notHiddenTokens(
                    walletID: walletID,
                    includesZeroBalanceItems: true,
                    limit: nil
                )
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
            
            var groups = Group.web3Chains(ids: chainIDs)
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
        let walletID = wallet.walletID
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self, queue] in
            guard !op.isCancelled else {
                return
            }
            let comparator = TokenComparator<BalancedSwapToken>(keyword: keyword)
            let localResults = Web3TokenDAO.shared
                .search(
                    walletID: walletID,
                    keyword: keyword,
                    includesZeroBalanceItems: true,
                    limit: nil
                )
                .compactMap(BalancedSwapToken.init(tokenItem:))
                .sorted(using: comparator)
            let chainIDs = Set(localResults.compactMap(\.chain.chainID))
            let localResultGroups = Group.web3Chains(ids: chainIDs)
            
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
                    source: .web3,
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
            var tokens = localResults.reduce(into: [:]) { results, token in
                results[token.assetID] = token
            }
            var hiddenAssetIDs: Set<String> = []
            
            // Tokens that exist in remote results, but not in local results
            let missingAssetIDs = remoteResults.compactMap { token in
                if let chainID = token.chain.chainID,
                   supportedChainIDs.contains(chainID),
                   tokens[token.assetID] == nil
                {
                    token.assetID
                } else {
                    nil
                }
            }
            if !missingAssetIDs.isEmpty {
                let missingTokens = Web3TokenDAO.shared.tokenItems(
                    walletID: wallet.walletID,
                    ids: missingAssetIDs
                )
                for token in missingTokens {
                    if token.isHidden {
                        hiddenAssetIDs.insert(token.assetID)
                    } else {
                        tokens[token.assetID] = BalancedSwapToken(tokenItem: token)
                    }
                }
            }
            
            var hasStockTokens = false
            var allItems: [String: BalancedSwapToken] = remoteResults.reduce(into: [:]) { result, token in
                guard let chainID = token.chain.chainID, supportedChainIDs.contains(chainID) else {
                    return
                }
                let assetID = token.assetID
                guard !hiddenAssetIDs.contains(assetID) else {
                    return
                }
                let localToken = tokens[assetID]
                hasStockTokens = hasStockTokens || token.category == .stock
                result[assetID] = BalancedSwapToken(
                    token: token,
                    balance: localToken?.decimalBalance ?? 0,
                    usdPrice: localToken?.decimalUSDPrice ?? 0,
                    isMalicious: localToken?.isMalicious ?? false,
                    level: localToken?.level ?? Reputation.Level.unknown.rawValue,
                )
            }
            for item in localResults where allItems[item.assetID] == nil {
                allItems[item.assetID] = item
            }
            let sortedAllItems = allItems.values.sorted(using: comparator)
            let chainIDs = Set(sortedAllItems.compactMap(\.chain.chainID))
            var groups = Group.web3Chains(ids: chainIDs)
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
