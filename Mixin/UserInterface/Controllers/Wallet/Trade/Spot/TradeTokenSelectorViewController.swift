import UIKit
import OrderedCollections
import Alamofire
import MixinServices

class TradeTokenSelectorViewController: ChainCategorizedTokenSelectorViewController<BalancedSwapToken> {
    
    let intent: TokenSelectorIntent
    let recentAssetIDsKey: PropertiesDAO.Key
    let stockTokens: [BalancedSwapToken]
    
    weak var searchRequest: Request?
    
    var onSelected: ((BalancedSwapToken) -> Void)?
    
    init(
        intent: TokenSelectorIntent,
        selectedAssetID: String?,
        defaultTokens: [BalancedSwapToken],
        stockTokens: [BalancedSwapToken],
    ) {
        self.intent = intent
        self.recentAssetIDsKey = switch intent {
        case .send:
                .mixinSwapRecentSendIDs
        case .receive:
                .mixinSwapRecentReceiveIDs
        }
        self.stockTokens = stockTokens
        super.init(
            defaultTokens: defaultTokens,
            defaultGroups: [],
            searchDebounceInterval: 0.5,
            selectedID: selectedAssetID
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        searchRequest?.cancel()
        operationQueue.cancelAllOperations()
    }
    
    override func prepareForSearch(_ textField: UITextField) {
        searchRequest?.cancel()
        operationQueue.cancelAllOperations()
        super.prepareForSearch(textField)
    }
    
    override func saveRecentsToStorage(tokens: any Sequence<BalancedSwapToken>) {
        PropertiesDAO.shared.set(
            jsonObject: tokens.map(\.assetID),
            forKey: recentAssetIDsKey
        )
    }
    
    override func clearRecentsStorage() {
        PropertiesDAO.shared.removeValue(forKey: recentAssetIDsKey)
    }
    
    override func tokens(from allTokens: [BalancedSwapToken], filteredBy group: Group) -> [BalancedSwapToken] {
        switch group {
        case .byCategory(let category):
            allTokens.filter { token in
                token.category == category
            }
        case .byChain(let chain):
            allTokens.filter { (token) in
                token.chain.chainID == chain.id
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
    
    override func configureTokenCell(_ cell: TradeTokenCell, withToken token: BalancedSwapToken) {
        cell.iconView.setIcon(swappableToken: token)
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
    
    override func pickUp(token: BalancedSwapToken, from location: PickUpLocation) {
        super.pickUp(token: token, from: location)
        presentingViewController?.dismiss(animated: true)
        onSelected?(token)
        reporter.report(event: .tradeTokenSelect, tags: ["method": location.asEventMethod])
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .groupSelector:
            guard searchResultGroups == nil || searchResults == nil else {
                fallthrough
            }
            guard indexPath.item != 0 else {
                fallthrough
            }
            if case .byCategory(.stock) = defaultGroups[indexPath.item - 1] {
                selectedGroup = .byCategory(.stock)
                tokensForSelectedGroup = stockTokens
                reloadWithoutAnimation(section: .tokens)
                reloadTokenSelection()
            } else {
                fallthrough
            }
        default:
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }
    
}
