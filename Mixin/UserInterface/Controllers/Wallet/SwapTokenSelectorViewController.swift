import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class SwapTokenSelectorViewController: TokenSelectorViewController<BalancedSwapToken> {
    
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
    private let walletID: String?
    
    private weak var searchRequest: Request?
    
    init(
        recent: Recent,
        tokens: [BalancedSwapToken],
        selectedAssetID: String?,
        walletID: String? = nil
    ) {
        self.recent = recent
        let chainIDs = Set(tokens.compactMap(\.chain.chainID))
        self.walletID = walletID
        let chains = if walletID != nil {
            Chain.web3Chains(ids: chainIDs)
        } else {
            Chain.mixinChains(ids: chainIDs)
        }
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadTokenSelection()
        DispatchQueue.global().async { [recent, weak self] in
            guard let tokens = PropertiesDAO.shared.jsonObject(forKey: recent.key, type: [SwapToken.Codable].self) else {
                return
            }
            let recentTokens = BalancedSwapToken.fillBalance(swappableTokens: tokens, walletID: self?.walletID)
            let assetIDs = recentTokens.map(\.assetID)
            let recentTokenChanges: [String: TokenChange] = MarketDAO.shared
                .priceChangePercentage24H(assetIDs: assetIDs)
                .compactMapValues(TokenChange.init(change:))
            DispatchQueue.main.async {
                self?.reloadRecents(tokens: recentTokens, changes: recentTokenChanges)
            }
        }
    }
    
    override func prepareForSearch(_ textField: UITextField) {
        searchRequest?.cancel()
        super.prepareForSearch(textField)
    }
    
    override func search(keyword: String) {
        let source: RouteTokenSource = walletID == nil ? .mixin : .web3
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
        switch location {
        case .recent:
            reporter.report(event: .swapCoinSwitch, method: "recent_click")
        case .allItems:
            reporter.report(event: .swapCoinSwitch, method: "all_item_click")
        case .chainFilteredItems:
            reporter.report(event: .swapCoinSwitch, method: "chain_item_click")
        case .searchResults:
            reporter.report(event: .swapCoinSwitch, method: "search_item_click")
        }
    }
    
    private func reloadSearchResults(keyword: String, tokens: [SwapToken]) {
        assert(!Thread.isMainThread)
        let searchResults = BalancedSwapToken.fillBalance(swappableTokens: tokens, walletID: walletID)
            .sorted { (one, another) in
                let left = (one.decimalBalance * one.decimalUSDPrice, one.decimalBalance, one.decimalUSDPrice)
                let right = (another.decimalBalance * another.decimalUSDPrice, another.decimalBalance, another.decimalUSDPrice)
                return left > right
            }
        let chainIDs = Set(tokens.compactMap(\.chain.chainID))
        let searchResultChains = Chain.mixinChains(ids: chainIDs)
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
