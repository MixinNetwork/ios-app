import UIKit
import Alamofire
import MixinServices

final class Web3TokenSelectorViewController: TokenSelectorViewController<Web3TokenItem> {
    
    var onSelected: ((Web3TokenItem) -> Void)?
    
    private let walletID: String
    
    private weak var searchRequest: Request?
    
    init(walletID: String, tokens: [Web3TokenItem]) {
        self.walletID = walletID
        let chainIDs = Set(tokens.compactMap(\.chainID))
        let chains = Chain.mixinChains(ids: chainIDs)
        super.init(
            defaultTokens: tokens,
            defaultChains: chains,
            searchDebounceInterval: 0.5,
            selectedID: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        searchRequest?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async { [defaultTokens] in
            let tokens = defaultTokens.reduce(into: [:]) { results, item in
                results[item.assetID] = item
            }
            let recentAssetIDs = PropertiesDAO.shared.jsonObject(forKey: .transferRecentAssetIDs, type: [String].self) ?? []
            let recentTokens = recentAssetIDs.compactMap { id in
                tokens[id]
            }
            let chainIDs = Set(defaultTokens.compactMap(\.chainID))
            let chains = Chain.web3Chains(ids: chainIDs)
            DispatchQueue.main.async {
                self.recentTokens = recentTokens
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
        super.prepareForSearch(textField)
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
        let searchResultChains = Chain.web3Chains(ids: chainIDs)
        
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
        self.reloadChainSelection()
        self.reloadTokenSelection()
        
        searchRequest = AssetAPI.search(keyword: keyword, queue: .global()) { [weak self] result in
            switch result {
            case .success(let tokens):
                self?.reloadSearchResults(keyword: keyword, tokens: tokens)
            case .failure(.emptyResponse):
                self?.reloadSearchResults(keyword: keyword, tokens: [])
            case .failure(let error):
                Logger.general.debug(category: "Web3TokenSelector", message: "\(error)")
                DispatchQueue.main.async {
                    self?.searchBoxView.isBusy = false
                }
            }
        }
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
    
    private func reloadSearchResults(keyword: String, tokens: [MixinToken]) {
        assert(!Thread.isMainThread)
        let supportedChainIDs: Set<String> = [
            ChainID.ethereum,
            ChainID.polygon,
            ChainID.bnbSmartChain,
            ChainID.base,
            ChainID.solana,
        ]
        let searchResults: [Web3TokenItem] = tokens.compactMap { token in
            guard supportedChainIDs.contains(token.chainID) else {
                return nil
            }
            let amount = Web3TokenDAO.shared.amount(walletID: walletID, assetID: token.assetID)
            let isHidden = Web3TokenExtraDAO.shared.isHidden(walletID: walletID, assetID: token.assetID)
            let chain = ChainDAO.shared.chain(chainId: token.chainID)
            let web3Token = Web3Token(
                walletID: walletID,
                assetID: token.assetID,
                chainID: token.chainID,
                assetKey: token.assetKey,
                kernelAssetID: token.kernelAssetID,
                symbol: token.symbol,
                name: token.name,
                precision: 0,
                iconURL: token.iconURL,
                amount: amount ?? "0",
                usdPrice: token.usdPrice,
                usdChange: token.usdChange,
                level: Web3Token.Level.verified.rawValue,
            )
            return Web3TokenItem(token: web3Token, hidden: isHidden, chain: chain)
        }.sorted { (one, another) in
            let left = (one.decimalBalance * one.decimalUSDPrice, one.decimalBalance, one.decimalUSDPrice)
            let right = (another.decimalBalance * another.decimalUSDPrice, another.decimalBalance, another.decimalUSDPrice)
            return left > right
        }
        let chainIDs = Set(searchResults.compactMap(\.chainID))
        let searchResultChains = Chain.mixinChains(ids: chainIDs)
        DispatchQueue.main.async {
            guard self.trimmedKeyword == keyword else {
                return
            }
            self.searchResultsKeyword = keyword
            self.searchResults = searchResults
            self.searchResultChains = searchResultChains
            if let chain = self.selectedChain, chainIDs.contains(chain.id) {
                self.tokenIndicesForSelectedChain = tokens.enumerated().compactMap { (index, token) in
                    if token.chainID == chain.id {
                        index
                    } else {
                        nil
                    }
                }
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
