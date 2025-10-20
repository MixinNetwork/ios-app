import UIKit
import OrderedCollections
import Alamofire
import MixinServices

class SwapTokenSelectorViewController: ChainCategorizedTokenSelectorViewController<BalancedSwapToken> {
    
    enum Intent {
        
        case send
        case receive
        
        fileprivate var recentAssetIDsKey: PropertiesDAO.Key {
            switch self {
            case .send:
                    .mixinSwapRecentSendIDs
            case .receive:
                    .mixinSwapRecentReceiveIDs
            }
        }
        
    }
    
    let intent: Intent
    
    var onSelected: ((BalancedSwapToken) -> Void)?
    
    private let supportedChainIDs: Set<String>? // nil for supporting all chains
    private let searchSource: RouteTokenSource
    
    private weak var searchRequest: Request?
    
    init(
        intent: Intent,
        supportedChainIDs: Set<String>?,
        searchSource: RouteTokenSource,
        tokens: [BalancedSwapToken],
        selectedAssetID: String?,
    ) {
        self.intent = intent
        self.supportedChainIDs = supportedChainIDs
        self.searchSource = searchSource
        let chainIDs = Set(tokens.compactMap(\.chain.chainID))
        let chains = Chain.web3Chains(ids: chainIDs)
        super.init(
            defaultTokens: tokens,
            defaultChains: chains,
            searchDebounceInterval: 1,
            selectedID: selectedAssetID
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        searchRequest?.cancel()
    }
    
    class func chains(with ids: Set<String>) -> OrderedSet<Chain> {
        assertionFailure("Must Override")
        return []
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadTokenSelection()
        DispatchQueue.global().async { [intent, supportedChainIDs, weak self] in
            let recentTokens = PropertiesDAO.shared.jsonObject(
                forKey: intent.recentAssetIDsKey,
                type: [SwapToken.Codable].self
            )
            guard let recentTokens else {
                return
            }
            let availableRecentTokens = if let supportedChainIDs {
                recentTokens.filter { token in
                    if let chainID = token.chain.chainID {
                        supportedChainIDs.contains(chainID)
                    } else {
                        false
                    }
                }
            } else {
                recentTokens
            }
            guard let tokens = self?.fillBalance(to: availableRecentTokens) else {
                return
            }
            let assetIDs = tokens.map(\.assetID)
            let changes: [String: TokenChange] = MarketDAO.shared
                .priceChangePercentage24H(assetIDs: assetIDs)
                .compactMapValues(TokenChange.init(change:))
            DispatchQueue.main.async {
                self?.reloadRecents(tokens: tokens, changes: changes)
            }
        }
    }
    
    override func prepareForSearch(_ textField: UITextField) {
        searchRequest?.cancel()
        super.prepareForSearch(textField)
    }
    
    override func search(keyword: String) {
        searchRequest = RouteAPI.search(
            keyword: keyword,
            source: searchSource,
            queue: .global()
        ) { [weak self] result in
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
    
    override func saveRecentsToStorage(tokens: any Sequence<BalancedSwapToken>) {
        let tokens = tokens.map(\.codable)
        PropertiesDAO.shared.set(jsonObject: tokens, forKey: intent.recentAssetIDsKey)
    }
    
    override func clearRecentsStorage() {
        PropertiesDAO.shared.removeValue(forKey: intent.recentAssetIDsKey)
    }
    
    override func tokenIndices(tokens: [BalancedSwapToken], chainID: String) -> [Int] {
        tokens.enumerated().compactMap { (index, token) in
            if token.chain.chainID == chainID {
                index
            } else {
                nil
            }
        }
    }
    
    override func configureRecentCell(_ cell: ExploreRecentSearchCell, withToken token: BalancedSwapToken) {
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
    }
    
    override func configureTokenCell(_ cell: SwapTokenCell, withToken token: BalancedSwapToken) {
        cell.iconView.setIcon(swappableToken: token)
        cell.maliciousWarningImageView.isHidden = true
        cell.titleLabel.text = token.name
        cell.subtitleLabel.text = token.localizedBalanceWithSymbol
        if let tag = token.chainTag {
            cell.chainLabel.text = tag
            cell.chainLabel.isHidden = false
        } else {
            cell.chainLabel.isHidden = true
        }
    }
    
    override func pickUp(token: BalancedSwapToken, from location: PickUpLocation) {
        super.pickUp(token: token, from: location)
        presentingViewController?.dismiss(animated: true)
        onSelected?(token)
        reporter.report(event: .tradeTokenSelect, tags: ["method": location.asEventMethod])
    }
    
    func fillBalance(to tokens: [SwapToken]) -> [BalancedSwapToken] {
        assertionFailure("Must Override")
        return []
    }
    
    private func reloadSearchResults(keyword: String, tokens: [SwapToken]) {
        assert(!Thread.isMainThread)
        let comparator = TokenComparator<BalancedSwapToken>(keyword: keyword)
        let searchResults = fillBalance(to: tokens)
            .sorted(using: comparator)
        let searchResultChainIDs = Set(searchResults.compactMap(\.chain.chainID))
        let searchResultChains = Self.chains(with: searchResultChainIDs)
        DispatchQueue.main.async {
            guard self.trimmedKeyword == keyword else {
                return
            }
            self.searchResultsKeyword = keyword
            self.searchResults = searchResults
            self.searchResultChains = searchResultChains
            if let chain = self.selectedChain, searchResultChainIDs.contains(chain.id) {
                self.tokenIndicesForSelectedChain = self.tokenIndices(tokens: searchResults, chainID: chain.id)
            } else {
                self.selectedChain = nil
                self.tokenIndicesForSelectedChain = nil
            }
            self.collectionView.reloadData()
            self.collectionView.checkEmpty(
                dataCount: searchResults.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
            self.reloadChainSelection()
            self.reloadTokenSelection()
            self.searchBoxView.isBusy = false
        }
    }
    
}
