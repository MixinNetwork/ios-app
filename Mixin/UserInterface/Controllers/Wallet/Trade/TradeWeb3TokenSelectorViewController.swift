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
        var remoteTokens = self.defaultTokens
        queue.async { [recentAssetIDsKey, supportedChainIDs] in
            // No need to filter with `supportedChainIDs`, the `walletID` will do
            // Unsupported tokens will not exist with the `walletID`
            var tokens = Web3TokenDAO.shared
                .notHiddenTokens(walletID: walletID, includesZeroBalanceItems: true)
                .compactMap(BalancedSwapToken.init(tokenItem:))
            var tokensMap = tokens.reduce(into: [:]) { results, token in
                results[token.assetID] = token
            }
            remoteTokens.removeAll { token in
                if tokensMap[token.assetID] != nil {
                    true
                } else if let chainID = token.chain.chainID {
                    !supportedChainIDs.contains(chainID)
                } else {
                    true
                }
            }
            tokens.append(contentsOf: remoteTokens)
            for token in remoteTokens {
                tokensMap[token.assetID] = token
            }
            let chainIDs = Set(tokens.compactMap(\.chain.chainID))
            let chains = Chain.web3Chains(ids: chainIDs)
            
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
            let localResultChains = Chain.web3Chains(ids: chainIDs)
            
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
                    source: .web3,
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
                        Logger.general.debug(category: "SwapWeb3TokenSelector", message: "\(error)")
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
            let walletID = wallet.walletID
            var allItems: [String: BalancedSwapToken] = remoteResults.reduce(into: [:]) { result, token in
                guard let chainID = token.chain.chainID, supportedChainIDs.contains(chainID) else {
                    return
                }
                let assetID = token.assetID
                let localResult = localResultsMap[assetID]
                let balance = localResult?.decimalBalance ?? {
                    guard let amount = Web3TokenDAO.shared.amount(walletID: walletID, assetID: assetID) else {
                        return nil
                    }
                    return Decimal(string: amount, locale: .enUSPOSIX)
                }()
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
            let chains = Chain.web3Chains(ids: chainIDs)
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
