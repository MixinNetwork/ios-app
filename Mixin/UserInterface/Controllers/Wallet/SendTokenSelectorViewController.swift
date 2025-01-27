import UIKit
import OrderedCollections
import MixinServices

extension TokenItem: SelectableToken { }

final class SendTokenSelectorViewController: TokenSelectorViewController<TokenItem> {
    
    var receiver: UserItem?
    
    init() {
        super.init(
            defaultTokens: [],
            defaultChains: [],
            searchDebounceInterval: 0.5,
            selectedAssetID: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async {
            let recentAssetIDs = PropertiesDAO.shared.jsonObject(forKey: .transferRecentAssetIDs, type: [String].self) ?? []
            let recentTokens = TokenDAO.shared.tokenItems(with: recentAssetIDs)
            let recentTokenChanges: [String: TokenChange] = MarketDAO.shared
                .priceChangePercentage24H(assetIDs: recentAssetIDs)
                .compactMapValues(TokenChange.init(change:))
            let tokens = TokenDAO.shared.positiveBalancedTokens()
            let chainIDs = Set(tokens.compactMap(\.chainID))
            let chains = Chain.chains(ids: chainIDs)
            DispatchQueue.main.async {
                self.recentTokens = recentTokens
                self.recentTokenChanges = recentTokenChanges
                self.defaultTokens = tokens
                self.defaultChains = chains
                self.collectionView.reloadData()
                self.collectionView.checkEmpty(
                    dataCount: tokens.count,
                    text: R.string.localizable.dont_have_assets(),
                    photo: R.image.emptyIndicator.ic_hidden_assets()!
                )
            }
        }
    }
    
    override func saveRecentsToStorage(tokens: any Sequence<TokenItem>) {
        PropertiesDAO.shared.set(
            jsonObject: tokens.map(\.assetID),
            forKey: .transferRecentAssetIDs
        )
    }
    
    override func clearRecentsStorage() {
        PropertiesDAO.shared.removeValue(forKey: .transferRecentAssetIDs)
    }
    
    override func search(keyword: String) {
        let searchResults = defaultTokens.filter { item in
            item.symbol.lowercased().contains(keyword) || item.name.lowercased().contains(keyword)
        }.sorted { (one, another) in
            let left = (one.decimalBalance * one.decimalUSDPrice, one.decimalBalance, one.decimalUSDPrice)
            let right = (another.decimalBalance * another.decimalUSDPrice, another.decimalBalance, another.decimalUSDPrice)
            return left > right
        }
        let chainIDs = Set(searchResults.compactMap(\.chainID))
        let searchResultChains = Chain.chains(ids: chainIDs)
        
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
    
    override func tokenIndices(tokens: [TokenItem], chainID: String) -> [Int] {
        tokens.enumerated().compactMap { (index, token) in
            if token.chainID == chainID {
                index
            } else {
                nil
            }
        }
    }
    
    override func configureRecentCell(_ cell: ExploreRecentSearchCell, withToken token: TokenItem) {
        cell.setBadgeIcon { iconView in
            iconView.setIcon(token: token)
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
    
    override func configureTokenCell(_ cell: SwapTokenCell, withToken token: TokenItem) {
        cell.iconView.setIcon(token: token)
        cell.titleLabel.text = token.name
        cell.subtitleLabel.text = token.localizedBalanceWithSymbol
        if let tag = token.chainTag {
            cell.chainLabel.text = tag
            cell.chainLabel.isHidden = false
        } else {
            cell.chainLabel.isHidden = true
        }
    }
    
    override func pickUp(token: TokenItem, from location: PickUpLocation) {
        let navigationController = UIApplication.homeNavigationController
        presentingViewController?.dismiss(animated: true) { [receiver] in
            if let receiver {
                let inputAmount = TransferInputAmountViewController(tokenItem: token, receiver: receiver)
                navigationController?.pushViewController(inputAmount, animated: true)
            } else {
                let receiver = TokenReceiverViewController(token: token)
                navigationController?.pushViewController(receiver, animated: true)
            }
        }
    }
    
}
