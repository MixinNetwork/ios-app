import UIKit
import OrderedCollections
import Alamofire
import MixinServices

class SwapTokenSelectorViewController: ChainCategorizedTokenSelectorViewController<BalancedSwapToken> {
    
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
    
    var onSelected: ((BalancedSwapToken) -> Void)?
    
    private let recent: Recent
    
    private weak var searchRequest: Request?
    
    var source: RouteTokenSource {
        .mixin
    }
    
    init(
        recent: Recent,
        tokens: [BalancedSwapToken],
        chains: OrderedSet<Chain>? = nil,
        selectedAssetID: String?
    ) {
        self.recent = recent
        let defaultChains = if let chains {
            chains
        } else {
            Chain.mixinChains(ids: Set(tokens.compactMap(\.chain.chainID)))
        }
        super.init(
            defaultTokens: tokens,
            defaultChains: defaultChains,
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadTokenSelection()
        DispatchQueue.global().async { [recent, weak self] in
            guard let tokens = PropertiesDAO.shared.jsonObject(forKey: recent.key, type: [SwapToken.Codable].self) else {
                return
            }
            let recentTokens = self?.filterRecentTokens(swappableTokens: tokens) ?? []
            let assetIDs = recentTokens.map(\.assetID)
            let recentTokenChanges: [String: TokenChange] = MarketDAO.shared
                .priceChangePercentage24H(assetIDs: assetIDs)
                .compactMapValues(TokenChange.init(change:))
            DispatchQueue.main.async {
                self?.reloadRecents(tokens: recentTokens, changes: recentTokenChanges)
            }
        }
    }
    
    func filterRecentTokens(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        fillSwappableTokenBalance(swappableTokens: swappableTokens)
    }
    
    override func prepareForSearch(_ textField: UITextField) {
        searchRequest?.cancel()
        super.prepareForSearch(textField)
    }
    
    override func search(keyword: String) {
        searchRequest = RouteAPI.search(keyword: keyword, source: source, queue: .global()) { [weak self] result in
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
        PropertiesDAO.shared.set(jsonObject: tokens, forKey: recent.key)
    }
    
    override func clearRecentsStorage() {
        PropertiesDAO.shared.removeValue(forKey: recent.key)
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
    
    func chains(with ids: Set<String>) -> OrderedSet<Chain> {
        Chain.mixinChains(ids: ids)
    }
    
    func fillSwappableTokenBalance(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        BalancedSwapToken.fillMixinBalance(swappableTokens: swappableTokens)
    }
    
    private func reloadSearchResults(keyword: String, tokens: [SwapToken]) {
        assert(!Thread.isMainThread)
        let searchResults = fillSwappableTokenBalance(swappableTokens: tokens)
            .sorted { $0.sortingValues > $1.sortingValues }
        let chainIDs = Set(tokens.compactMap(\.chain.chainID))
        let searchResultChains = chains(with: chainIDs)
        DispatchQueue.main.async {
            guard self.trimmedKeyword == keyword else {
                return
            }
            self.searchResultsKeyword = keyword
            self.searchResults = searchResults
            self.searchResultChains = searchResultChains
            if let chain = self.selectedChain, chainIDs.contains(chain.id) {
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
