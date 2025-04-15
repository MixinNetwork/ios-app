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
    
    override func review(_ sender: RoundedButton) {
        guard let quote else {
            return
        }
        guard let walletID else {
            return
        }
        guard let chainID = sendTokenChainID else {
            return
        }
        guard let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: chainID) else {
            return
        }
        
        let request = SwapRequest(
            sendToken: quote.sendToken,
            sendAmount: quote.sendAmount,
            receiveToken: quote.receiveToken,
            source: quote.source,
            slippage: 0.01,
            payload: quote.payload,
            withdrawalDestination: address.destination
        )
        sender.isBusy = true
        let job = AddBotIfNotFriendJob(userID: BotUserID.mixinRoute)
        ConcurrentJobQueue.shared.addJob(job: job)
        RouteAPI.swap(request: request) { [weak self] response in
            guard self != nil else {
                return
            }
            switch response {
            case .success(let response):
                guard
                    let depositDestination = response.depositDestination,
                    let receiveAmount = Decimal(string: response.quote.outAmount, locale: .enUSPOSIX)
                else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                    sender.isBusy = false
                    return
                }
                
                Task { [weak self] in
                    guard let sendToken = Web3TokenDAO.shared.token(walletID: chainID, assetID: quote.sendToken.assetID) else {
                        return
                    }
                    guard let homeContainer = UIApplication.homeContainerViewController else {
                        return
                    }
                    guard let chain = Web3Chain.chain(chainID: chainID) else {
                        return
                    }
                    
                    let sendAmount = quote.sendAmount
                    let payment = Web3SendingTokenPayment(chain: chain, token: sendToken, fromAddress: address.destination)
                    let addressPayment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        to: .arbitrary,
                        address: address.destination
                    )
                    let operation = switch chain.kind {
                    case .evm:
                        try EVMTransferToAddressOperation(payment: addressPayment, decimalAmount: sendAmount)
                    case .solana:
                        try SolanaTransferToAddressOperation(payment: addressPayment, decimalAmount: sendAmount)
                    }
                    let fee = try await operation.loadFee()
                    let feeTokenSymbol = operation.feeToken.symbol
                    
                    await MainActor.run {
                        let op = SwapPaymentOperation(operation: operation, sendToken: quote.sendToken, sendAmount: sendAmount, receiveToken: quote.receiveToken, receiveAmount: receiveAmount, destination: .address(address.destination, fee, feeTokenSymbol), memo: nil)
                        
                        let preview = SwapPreviewViewController(operation: op, warnings: [])
                        homeContainer.present(preview, animated: true)
                    }
                }
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                sender.isBusy = false
            }
        }
        reporter.report(event: .swapPreview)
    }
}
