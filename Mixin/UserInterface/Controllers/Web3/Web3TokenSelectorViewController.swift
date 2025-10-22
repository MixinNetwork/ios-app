import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class Web3TokenSelectorViewController: ChainCategorizedTokenSelectorViewController<Web3TokenItem> {
    
    var onSelected: ((Web3TokenItem) -> Void)?
    
    private let wallet: Web3Wallet
    private let supportedChainIDs: Set<String>
    private let intent: TokenSelectorIntent
    private let displayZeroBalanceItems: Bool
    
    private weak var searchRequest: Request?
    
    init(
        wallet: Web3Wallet,
        supportedChainIDs: Set<String>,
        intent: TokenSelectorIntent,
    ) {
        self.wallet = wallet
        self.supportedChainIDs = supportedChainIDs
        self.intent = intent
        self.displayZeroBalanceItems = switch intent {
        case .send:
            false
        case .receive:
            true
        }
        super.init(
            defaultTokens: [],
            defaultChains: [],
            searchDebounceInterval: 0.5,
            selectedID: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        searchRequest?.cancel()
        operationQueue.cancelAllOperations()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let walletID = wallet.walletID
        queue.async { [displayZeroBalanceItems] in
            let tokens = Web3TokenDAO.shared.notHiddenTokens(
                walletID: walletID,
                includesZeroBalanceItems: displayZeroBalanceItems,
            )
            let chainIDs = Set(tokens.compactMap(\.chainID))
            let chains = Chain.web3Chains(ids: chainIDs)
            let tokensMap = tokens.reduce(into: [:]) { results, token in
                results[token.assetID] = token
            }
            let recentAssetIDs = PropertiesDAO.shared.jsonObject(forKey: .transferRecentAssetIDs, type: [String].self) ?? []
            let recentTokens = recentAssetIDs.compactMap { id in
                tokensMap[id]
            }
            DispatchQueue.main.async {
                self.recentTokens = recentTokens
                self.defaultTokens = tokens
                self.defaultChains = chains
                self.collectionView.reloadData()
                self.reloadChainSelection()
                self.collectionView.checkEmpty(
                    dataCount: tokens.count,
                    text: R.string.localizable.dont_have_assets(),
                    photo: R.image.emptyIndicator.ic_hidden_assets()!
                )
            }
        }
    }
    
    override func saveRecentsToStorage(tokens: any Sequence<Web3TokenItem>) {
        PropertiesDAO.shared.set(
            jsonObject: tokens.map(\.assetID),
            forKey: .transferRecentAssetIDs
        )
    }
    
    override func clearRecentsStorage() {
        PropertiesDAO.shared.removeValue(forKey: .transferRecentAssetIDs)
    }
    
    override func prepareForSearch(_ textField: UITextField) {
        searchRequest?.cancel()
        operationQueue.cancelAllOperations()
        super.prepareForSearch(textField)
    }
    
    override func search(keyword: String) {
        let walletID = wallet.walletID
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self, intent, displayZeroBalanceItems] in
            guard !op.isCancelled else {
                return
            }
            let comparator = TokenComparator<Web3TokenItem>(keyword: keyword)
            let localResults = Web3TokenDAO.shared
                .search(
                    walletID: walletID,
                    keyword: keyword,
                    includesZeroBalanceItems: displayZeroBalanceItems,
                    limit: nil
                )
                .sorted(using: comparator)
            let chainIDs = Set(localResults.compactMap(\.chainID))
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
                
                guard intent == .receive else {
                    // Search from remote only when receiving
                    // Sending requires non-zero balance, which must be included in `localResults`
                    self.collectionView.checkEmpty(
                        dataCount: localResults.count,
                        text: R.string.localizable.no_results(),
                        photo: R.image.emptyIndicator.ic_search_result()!
                    )
                    self.searchBoxView.isBusy = false
                    return
                }
                self.searchRequest = AssetAPI.search(
                    keyword: keyword,
                    queue: self.queue
                ) { [weak self] result in
                    switch result {
                    case .success(let tokens):
                        self?.reloadSearchResults(
                            keyword: keyword,
                            localResults: localResults,
                            remoteResults: tokens,
                            comparator: comparator
                        )
                    case .failure(.emptyResponse):
                        self?.reloadSearchResults(
                            keyword: keyword,
                            localResults: localResults,
                            remoteResults: [],
                            comparator: comparator
                        )
                    case .failure(let error):
                        Logger.general.debug(category: "Web3TokenSelector", message: "\(error)")
                        DispatchQueue.main.async {
                            self?.searchBoxView.isBusy = false
                        }
                    }
                }
            }
        }
        operationQueue.addOperation(op)
    }
    
    override func tokenIndices(tokens: [Web3TokenItem], chainID: String) -> [Int] {
        tokens.enumerated().compactMap { (index, token) in
            if token.chainID == chainID {
                index
            } else {
                nil
            }
        }
    }
    
    override func configureRecentCell(_ cell: ExploreRecentSearchCell, withToken token: Web3Token) {
        cell.setBadgeIcon { iconView in
            iconView.setIcon(web3Token: token)
        }
        cell.titleLabel.text = token.symbol
        cell.subtitleLabel.marketColor = .byValue(token.decimalUSDChange)
        cell.subtitleLabel.text = token.localizedUSDChange
    }
    
    override func configureTokenCell(_ cell: SwapTokenCell, withToken token: Web3Token) {
        cell.iconView.setIcon(web3Token: token)
        cell.maliciousWarningImageView.isHidden = !token.isMalicious
        cell.titleLabel.text = token.name
        cell.subtitleLabel.text = token.localizedBalanceWithSymbol
        if let tag = token.chainTag {
            cell.chainLabel.text = tag
            cell.chainLabel.isHidden = false
        } else {
            cell.chainLabel.isHidden = true
        }
    }
    
    override func pickUp(token: Web3TokenItem, from location: PickUpLocation) {
        super.pickUp(token: token, from: location)
        presentingViewController?.dismiss(animated: true) { [onSelected] in
            onSelected?(token)
        }
    }
    
    private func reloadSearchResults(
        keyword: String,
        localResults: [Web3TokenItem],
        remoteResults: [MixinToken],
        comparator: TokenComparator<Web3TokenItem>,
    ) {
        assert(!Thread.isMainThread)
        let mixedSearchResults: (items: [Web3TokenItem], chains: OrderedSet<Chain>, chainIDs: Set<String>)?
        if remoteResults.isEmpty {
            mixedSearchResults = nil
        } else {
            let walletID = wallet.walletID
            let supportedChains = Web3ChainDAO.shared.chains(chainIDs: supportedChainIDs)
            var allItems: [String: Web3TokenItem] = remoteResults.reduce(into: [:]) { result, token in
                guard let chain = supportedChains[token.chainID] else {
                    return
                }
                let assetID = token.assetID
                let amount = Web3TokenDAO.shared.amount(walletID: walletID, assetID: assetID)
                let level = Web3TokenDAO.shared.level(walletID: walletID, assetID: assetID)
                let web3Token = Web3Token(
                    walletID: walletID,
                    assetID: assetID,
                    chainID: token.chainID,
                    assetKey: token.assetKey,
                    kernelAssetID: token.kernelAssetID,
                    symbol: token.symbol,
                    name: token.name,
                    precision: token.precision,
                    iconURL: token.iconURL,
                    amount: amount ?? "0",
                    usdPrice: token.usdPrice,
                    usdChange: token.usdChange,
                    level: level ?? Web3Reputation.Level.verified.rawValue,
                )
                let isHidden = Web3TokenExtraDAO.shared.isHidden(walletID: walletID, assetID: assetID)
                result[assetID] = Web3TokenItem(token: web3Token, hidden: isHidden, chain: chain)
            }
            for item in localResults where allItems[item.assetID] == nil {
                allItems[item.assetID] = item
            }
            let sortedAllItems = allItems.values.sorted(using: comparator)
            let chainIDs = Set(sortedAllItems.map(\.chainID))
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
            self.collectionView.checkEmpty(
                dataCount: self.searchResults?.count ?? 0,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
            self.searchBoxView.isBusy = false
        }
    }
    
}
