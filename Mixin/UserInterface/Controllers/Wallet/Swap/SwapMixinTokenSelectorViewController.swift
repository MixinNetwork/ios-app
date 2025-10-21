import UIKit
import OrderedCollections
import MixinServices

final class SwapMixinTokenSelectorViewController: SwapTokenSelectorViewController {
    
    init(
        intent: TokenSelectorIntent,
        tokens: [BalancedSwapToken],
        selectedAssetID: String?
    ) {
        super.init(
            intent: intent,
            supportedChainIDs: nil,
            searchSource: .mixin,
            tokens: tokens,
            selectedAssetID: selectedAssetID
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override class func chains(with ids: Set<String>) -> OrderedSet<Chain> {
        Chain.mixinChains(ids: ids)
    }
    
    override func fillBalance(to tokens: [SwapToken]) -> [BalancedSwapToken] {
        let ids = tokens.map(\.assetID)
        let tokenItems = TokenDAO.shared
            .tokenItems(with: ids)
            .reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
        return tokens.map { token in
            if let item = tokenItems[token.assetID] {
                BalancedSwapToken(token: token, balance: item.decimalBalance, usdPrice: item.decimalUSDPrice)
            } else {
                BalancedSwapToken(token: token, balance: 0, usdPrice: 0)
            }
        }
    }
    
}
