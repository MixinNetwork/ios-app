import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class MixinTokenSelectorViewController: TokenSelectorViewController<MixinTokenItem> {
    
    var onSelected: ((MixinTokenItem, PickUpLocation) -> Void)?
    var searchFromRemote = false
    
    private weak var searchRequest: Request?
    
    init() {
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async {
            let recentAssetIDs = PropertiesDAO.shared.jsonObject(forKey: .transferRecentAssetIDs, type: [String].self) ?? []
            let recentTokens = TokenDAO.shared.tokenItems(with: recentAssetIDs)
                .reduce(into: [:]) { results, item in
                    results[item.assetID] = item
                }
            let orderedRecentTokens = recentAssetIDs.compactMap { id in
                recentTokens[id]
            }
            let recentTokenChanges: [String: TokenChange] = MarketDAO.shared
                .priceChangePercentage24H(assetIDs: recentAssetIDs)
                .compactMapValues(TokenChange.init(change:))
            let tokens = TokenDAO.shared.positiveBalancedTokens()
            let chainIDs = Set(tokens.compactMap(\.chainID))
            let chains = Chain.mixinChains(ids: chainIDs)
            DispatchQueue.main.async {
                self.recentTokens = orderedRecentTokens
                self.recentTokenChanges = recentTokenChanges
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
    
    override func saveRecentsToStorage(tokens: any Sequence<MixinTokenItem>) {
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
        let searchResultChains = Chain.mixinChains(ids: chainIDs)
        
        self.searchResultsKeyword = keyword
        self.searchResults = searchResults
        self.searchResultChains = searchResultChains
        if let chain = self.selectedChain, chainIDs.contains(chain.id) {
            tokenIndicesForSelectedChain = tokenIndices(tokens: searchResults, chainID: chain.id)
        } else {
            selectedChain = nil
            tokenIndicesForSelectedChain = nil
        }
        collectionView.reloadData()
        reloadChainSelection()
        reloadTokenSelection()
        
        if searchFromRemote {
            searchRequest = AssetAPI.search(keyword: keyword, queue: .global()) { [weak self] result in
                switch result {
                case .success(let tokens):
                    self?.reloadSearchResults(keyword: keyword, localTokens: searchResults, searchResults: tokens)
                case .failure(.emptyResponse):
                    self?.reloadSearchResults(keyword: keyword, localTokens: searchResults, searchResults: [])
                case .failure(let error):
                    Logger.general.debug(category: "MixinTokenSelector", message: "\(error)")
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        self.collectionView.checkEmpty(
                            dataCount: searchResults.count,
                            text: R.string.localizable.no_results(),
                            photo: R.image.emptyIndicator.ic_search_result()!
                        )
                        self.searchBoxView.isBusy = false
                    }
                }
            }
        } else {
            collectionView.checkEmpty(
                dataCount: searchResults.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
            searchBoxView.isBusy = false
        }
    }
    
    override func tokenIndices(tokens: [MixinTokenItem], chainID: String) -> [Int] {
        tokens.enumerated().compactMap { (index, token) in
            if token.chainID == chainID {
                index
            } else {
                nil
            }
        }
    }
    
    override func configureRecentCell(_ cell: ExploreRecentSearchCell, withToken token: MixinTokenItem) {
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
    
    override func configureTokenCell(_ cell: SwapTokenCell, withToken token: MixinTokenItem) {
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
    
    override func pickUp(token: MixinTokenItem, from location: PickUpLocation) {
        super.pickUp(token: token, from: location)
        presentingViewController?.dismiss(animated: true) { [onSelected] in
            onSelected?(token, location)
        }
    }
    
    private func reloadSearchResults(
        keyword: String,
        localTokens: [MixinTokenItem],
        searchResults: [MixinToken]
    ) {
        assert(!Thread.isMainThread)
        let localAssetIDs = Set(localTokens.map(\.assetID))
        let allChains = ChainDAO.shared.allChains()
        let allSearchResults = localTokens + searchResults.filter{ token in
            !localAssetIDs.contains(token.assetID)
        }.compactMap { token in
            MixinTokenItem(
                token: token,
                balance: "0",
                isHidden: false,
                chain: allChains[token.chainID]
            )
        }.sorted { (one, another) in
            one.decimalUSDPrice > another.decimalUSDPrice
        }
        let chainIDs = Set(allSearchResults.compactMap(\.chainID))
        let searchResultChains = Chain.mixinChains(ids: chainIDs)
        DispatchQueue.main.async {
            guard self.trimmedKeyword == keyword else {
                return
            }
            self.searchResultsKeyword = keyword
            self.searchResults = allSearchResults
            self.searchResultChains = searchResultChains
            if let chain = self.selectedChain, chainIDs.contains(chain.id) {
                self.tokenIndicesForSelectedChain = allSearchResults
                    .enumerated()
                    .compactMap { (index, token) in
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
                dataCount: allSearchResults.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
            self.reloadChainSelection()
            self.reloadTokenSelection()
            self.searchBoxView.isBusy = false
        }
    }
    
}
