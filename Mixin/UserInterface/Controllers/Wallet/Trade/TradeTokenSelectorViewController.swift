import UIKit
import OrderedCollections
import Alamofire
import MixinServices

class TradeTokenSelectorViewController: ChainCategorizedTokenSelectorViewController<BalancedSwapToken> {
    
    let intent: TokenSelectorIntent
    let recentAssetIDsKey: PropertiesDAO.Key
    
    weak var searchRequest: Request?
    
    var onSelected: ((BalancedSwapToken) -> Void)?
    
    init(
        intent: TokenSelectorIntent,
        selectedAssetID: String?,
        defaultTokens: [BalancedSwapToken],
    ) {
        self.intent = intent
        self.recentAssetIDsKey = switch intent {
        case .send:
                .mixinSwapRecentSendIDs
        case .receive:
                .mixinSwapRecentReceiveIDs
        }
        super.init(
            defaultTokens: defaultTokens,
            defaultChains: [],
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
    
    override func configureTokenCell(_ cell: TradeTokenCell, withToken token: BalancedSwapToken) {
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
    
}
