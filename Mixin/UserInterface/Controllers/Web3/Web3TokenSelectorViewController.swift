import UIKit
import MixinServices

extension Web3Token: IdentifiableToken {
    
    var id: String {
        fungibleID
    }
    
}

final class Web3TokenSelectorViewController: TokenSelectorViewController<Web3Token> {
    
    var onSelected: ((Web3Token) -> Void)?
    
    init(tokens: [Web3Token]) {
        super.init(
            defaultTokens: tokens,
            defaultChains: [],
            searchDebounceInterval: 0.5,
            selectedID: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async { [tokens=defaultTokens] in
            let recentFungibleIDs = Set(PropertiesDAO.shared.jsonObject(forKey: .web3RecentFungibleIDs, type: [String].self) ?? [])
            let recentTokens = tokens.filter { token in
                recentFungibleIDs.contains(token.fungibleID)
            }
            let chainIDs = Set(tokens.compactMap(\.chainID))
            let chains = Chain.chains(ids: chainIDs)
            DispatchQueue.main.async {
                self.recentTokens = recentTokens
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
    
    override func saveRecentsToStorage(tokens: any Sequence<Web3Token>) {
        PropertiesDAO.shared.set(
            jsonObject: tokens.map(\.fungibleID),
            forKey: .web3RecentFungibleIDs
        )
    }
    
    override func clearRecentsStorage() {
        PropertiesDAO.shared.removeValue(forKey: .web3RecentFungibleIDs)
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
    
    override func tokenIndices(tokens: [Web3Token], chainID: String) -> [Int] {
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
        cell.subtitleLabel.marketColor = token.decimalPercentChange >= 0 ? .rising : .falling
        cell.subtitleLabel.text = token.localizedPercentChange
    }
    
    override func configureTokenCell(_ cell: SwapTokenCell, withToken token: Web3Token) {
        cell.iconView.setIcon(web3Token: token)
        cell.titleLabel.text = token.name
        cell.subtitleLabel.text = token.localizedBalanceWithSymbol
        if let tag = token.chainTag {
            cell.chainLabel.text = tag
            cell.chainLabel.isHidden = false
        } else {
            cell.chainLabel.isHidden = true
        }
    }
    
    override func pickUp(token: Web3Token, from location: PickUpLocation) {
        super.pickUp(token: token, from: location)
        presentingViewController?.dismiss(animated: true) { [onSelected] in
            onSelected?(token)
        }
    }
    
}
