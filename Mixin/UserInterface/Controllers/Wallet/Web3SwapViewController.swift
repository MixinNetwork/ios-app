import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class Web3SwapViewController: MixinSwapViewController {
    
    override var source: RouteTokenSource {
        return .web3
    }
 
    init(walletID: String) {
        super.init(sendAssetID: nil, receiveAssetID: nil, walletID: walletID)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initTitleBar() {
        navigationItem.titleView = NavigationTitleView(
            title: R.string.localizable.swap(),
            subtitle: R.string.localizable.common_wallet()
        )
        navigationItem.rightBarButtonItems = [
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            )
        ]
    }
    
    override func depositSendToken(_ sender: Any) {
        guard let walletID else {
            return
        }
        guard let chainID = sendTokenChainID else {
            return
        }
        guard let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: chainID) else {
            return
        }
        guard let kind = Web3Chain.chain(chainID: chainID)?.kind else {
            return
        }
        
        let deposit = Web3DepositViewController(kind: kind, address: address.destination)
        navigationController?.pushViewController(deposit, animated: true)
    }
    
    override func fetchBalancedSwapToken(assetID: String) -> BalancedSwapToken? {
        guard let walletID else {
            return nil
        }
        guard let item = Web3TokenDAO.shared.token(walletID: walletID, assetID: assetID), let token = BalancedSwapToken(tokenItem: item) else {
            return nil
        }
        return token
    }
    
    override func makeRequest(swapQuote: SwapQuote) -> SwapRequest? {
        guard let walletID else {
            return nil
        }
        guard let chainID = sendTokenChainID else {
            return nil
        }
        guard let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: chainID) else {
            return nil
        }
        return SwapRequest(
            sendToken: swapQuote.sendToken,
            sendAmount: swapQuote.sendAmount,
            receiveToken: swapQuote.receiveToken,
            source: swapQuote.source,
            slippage: 0.01,
            payload: swapQuote.payload,
            withdrawalDestination: address.destination
        )
    }
}
