import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class Web3SwapViewController: MixinSwapViewController {
    
    private let wallet: Web3Wallet
    
    override var source: RouteTokenSource {
        return .web3
    }
    
    private var walletID: String {
        wallet.walletID
    }
    
    init(wallet: Web3Wallet, sendAssetID: String?, receiveAssetID: String?) {
        self.wallet = wallet
        super.init(sendAssetID: sendAssetID, receiveAssetID: receiveAssetID, referral: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initTitleBar() {
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.swap(),
            wallet: .common(wallet)
        )
        navigationItem.rightBarButtonItems = [
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            )
        ]
    }
    
    override func fillSwappableTokenBalance(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        BalancedSwapToken.fillWeb3Balance(swappableTokens: swappableTokens, walletID: wallet.walletID)
    }
    
    override func getTokenSelectorViewController(recent: SwapTokenSelectorViewController.Recent) -> SwapTokenSelectorViewController {
        let tokens: [BalancedSwapToken]
        let selectedAssetID: String?
        switch recent {
        case .send:
            tokens = swappableTokens.values.sorted { $0.sortingValues > $1.sortingValues }
            selectedAssetID = sendToken?.assetID
        case .receive:
            tokens = Array(swappableTokens.values)
            selectedAssetID = receiveToken?.assetID
        }
        
        return Web3SwapTokenSelectorViewController(
            wallet: wallet,
            recent: recent,
            tokens: tokens,
            selectedAssetID: selectedAssetID
        )
    }
    
    override func depositSendToken(_ sender: Any) {
        guard let chainID = sendToken?.chain.chainID else {
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
        guard let item = Web3TokenDAO.shared.token(walletID: walletID, assetID: assetID), let token = BalancedSwapToken(tokenItem: item) else {
            return nil
        }
        return token
    }
    
    override func review(_ sender: RoundedButton) {
        guard let quote else {
            return
        }
        guard let sendTokenChainID = sendToken?.chain.chainID, let receiveTokenChainID = receiveToken?.chain.chainID else {
            return
        }
        guard let receiveAddress = Web3AddressDAO.shared.address(walletID: walletID, chainID: receiveTokenChainID) else {
            return
        }
        guard let sendingAddress = Web3AddressDAO.shared.address(walletID: walletID, chainID: sendTokenChainID) else {
            return
        }
        
        let request = SwapRequest(
            sendToken: quote.sendToken,
            sendAmount: quote.sendAmount,
            receiveToken: quote.receiveToken,
            source: .web3,
            slippage: 0.01,
            payload: quote.payload,
            withdrawalDestination: receiveAddress.destination,
            referral: nil
        )
        sender.isBusy = true
        let job = AddBotIfNotFriendJob(userID: BotUserID.mixinRoute)
        ConcurrentJobQueue.shared.addJob(job: job)
        RouteAPI.swap(request: request) { [weak self, wallet] response in
            guard self != nil else {
                return
            }
            switch response {
            case .success(let response):
                guard
                    let depositDestination = response.depositDestination,
                    quote.sendToken.assetID == response.quote.inputMint,
                    quote.receiveToken.assetID == response.quote.outputMint,
                    let sendAmount = Decimal(string: response.quote.inAmount, locale: .enUSPOSIX),
                    let receiveAmount = Decimal(string: response.quote.outAmount, locale: .enUSPOSIX)
                else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                    sender.isBusy = false
                    return
                }
                
                Task {
                    guard let displayReceiver = await self?.fetchUser(userID: response.displayUserId, sender: sender) else {
                        return
                    }
                    guard let sendToken = Web3TokenDAO.shared.token(walletID: wallet.walletID, assetID: quote.sendToken.assetID) else {
                        return
                    }
                    guard let sendChain = Web3Chain.chain(chainID: sendTokenChainID) else {
                        return
                    }
                    
                    let payment = Web3SendingTokenPayment(
                        wallet: wallet,
                        chain: sendChain,
                        token: sendToken,
                        fromAddress: sendingAddress
                    )
                    let addressPayment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        to: .arbitrary,
                        address: depositDestination
                    )
                    
                    do {
                        let operation = switch sendChain.specification {
                        case .evm(let id):
                            try EVMTransferToAddressOperation(
                                evmChainID: id,
                                payment: addressPayment,
                                decimalAmount: sendAmount
                            )
                        case .solana:
                            try SolanaTransferToAddressOperation(
                                payment: addressPayment,
                                decimalAmount: sendAmount
                            )
                        }
                        
                        let fee = try await operation.loadFee()
                        let feeTokenSymbol = operation.feeToken.symbol
                        
                        let sendRequirement = BalanceRequirement(token: sendToken, amount: sendAmount)
                        let feeRequirement = BalanceRequirement(token: operation.feeToken, amount: fee.tokenAmount)
                        let requirements = sendRequirement.merging(with: feeRequirement)
                        let isBalanceSufficient = requirements.allSatisfy(\.isSufficient)
                        
                        await MainActor.run {
                            guard let homeContainer = UIApplication.homeContainerViewController else {
                                return
                            }
                            guard isBalanceSufficient else {
                                sender.isBusy = false
                                let insufficient = InsufficientBalanceViewController(
                                    intent: .commonWalletTransfer(
                                        wallet: wallet,
                                        transferring: sendRequirement,
                                        fee: feeRequirement
                                    )
                                )
                                homeContainer.present(insufficient, animated: true)
                                return
                            }
                            let destination = SwapOperation.Web3Destination(
                                displayReceiver: displayReceiver,
                                depositDestination: depositDestination,
                                fee: fee,
                                feeTokenSymbol: feeTokenSymbol,
                                senderAddress: sendingAddress
                            )
                            let operation = SwapOperation(
                                operation: operation,
                                sendToken: quote.sendToken,
                                sendAmount: sendAmount,
                                receiveToken: quote.receiveToken,
                                receiveAmount: receiveAmount,
                                destination: .web3(destination),
                                memo: nil
                            )
                            let preview = SwapPreviewViewController(
                                wallet: .common(wallet),
                                operation: operation,
                                warnings: []
                            )
                            preview.onDismiss = {
                                sender.isBusy = false
                            }
                            homeContainer.present(preview, animated: true)
                        }
                    } catch {
                        showAutoHiddenHud(style: .error, text: "\(error)")
                        sender.isBusy = false
                    }
                }
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                sender.isBusy = false
            }
        }
        reporter.report(event: .tradePreview)
    }
    
    private func fetchUser(userID: String, sender: RoundedButton) async -> UserItem? {
        var receiveUser = UserDAO.shared.getUser(userId: userID)
        if receiveUser == nil {
            switch UserAPI.showUser(userId: userID) {
            case let .success(user):
                UserDAO.shared.updateUsers(users: [user])
                receiveUser = UserItem.createUser(from: user)
            case let .failure(error):
                await MainActor.run {
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    sender.isBusy = false
                }
            }
        }
        return receiveUser
    }
}
