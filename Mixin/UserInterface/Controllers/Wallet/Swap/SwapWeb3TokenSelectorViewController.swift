import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class SwapWeb3TokenSelectorViewController: SwapTokenSelectorViewController {
    
    private let wallet: Web3Wallet
    
    init(
        wallet: Web3Wallet,
        supportedChainIDs: Set<String>,
        recent: Recent,
        tokens: [BalancedSwapToken],
        selectedAssetID: String?,
    ) {
        self.wallet = wallet
        super.init(
            recent: recent,
            supportedChainIDs: supportedChainIDs,
            searchSource: .web3,
            tokens: tokens,
            selectedAssetID: selectedAssetID
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class func chains(with ids: Set<String>) -> OrderedSet<Chain> {
        Chain.web3Chains(ids: ids)
    }
    
    override func fillBalance(to tokens: [SwapToken]) -> [BalancedSwapToken] {
        let ids = tokens.map(\.assetID)
        let tokenItems = Web3TokenDAO.shared
            .tokens(walletID: wallet.walletID, ids: ids)
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
