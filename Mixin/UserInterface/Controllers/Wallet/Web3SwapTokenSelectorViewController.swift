import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class Web3SwapTokenSelectorViewController: SwapTokenSelectorViewController {
    
    private let walletID: String
    
    override var source: RouteTokenSource {
        .web3
    }
    
    init(
        recent: Recent,
        tokens: [BalancedSwapToken],
        selectedAssetID: String?,
        walletID: String
    ) {
        self.walletID = walletID
        let chainIDs = Set(tokens.compactMap(\.chain.chainID))
        let chains = Chain.web3Chains(ids: chainIDs)
        super.init(recent: recent, tokens: tokens, chains: chains, selectedAssetID: selectedAssetID)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func filterRecentTokens(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        let recentTokens = super.filterRecentTokens(swappableTokens: swappableTokens)
        
        let chains = defaultChains.reduce(into: [:]) { results, item in
            results[item.id] = item
        }
        return recentTokens.compactMap { token in
            guard let chainID = token.chain.chainID else {
                return nil
            }
            return chains[chainID] != nil ? token : nil
        }
    }
    
    override func fillSwappableTokenBalance(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        BalancedSwapToken.fillWeb3Balance(swappableTokens: swappableTokens, walletID: walletID)
    }
    
    override func chains(with ids: Set<String>) -> OrderedSet<Chain> {
        Chain.web3Chains(ids: ids)
    }
}
