import UIKit
import OrderedCollections
import MixinServices

final class Web3SwapViewController: SwapViewController {
    
    private let wallet: Web3Wallet
    private let supportedChainIDs: Set<String>
    
    private var walletID: String {
        wallet.walletID
    }
    
    init(wallet: Web3Wallet, sendAssetID: String?, receiveAssetID: String?) {
        self.wallet = wallet
        self.supportedChainIDs = Web3AddressDAO.shared.chainIDs(walletID: wallet.walletID)
        super.init(
            tokenSource: .web3,
            sendAssetID: sendAssetID,
            receiveAssetID: receiveAssetID
        )
    }
    
    init(
        wallet: Web3Wallet,
        supportedChainIDs: Set<String>,
        sendAssetID: String?,
        receiveAssetID: String?
    ) {
        self.wallet = wallet
        self.supportedChainIDs = supportedChainIDs
        super.init(
            tokenSource: .web3,
            sendAssetID: sendAssetID,
            receiveAssetID: receiveAssetID
        )
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    override func changeSendToken(_ sender: Any) {
        let tokens = swappableTokens.values.sorted {
            $0.sortingValues > $1.sortingValues
        }
        let selector = SwapWeb3TokenSelectorViewController(
            wallet: wallet,
            supportedChainIDs: supportedChainIDs,
            intent: .send,
            tokens: tokens,
            selectedAssetID: sendToken?.assetID
        )
        selector.onSelected = { token in
            if token.assetID == self.receiveToken?.assetID {
                self.swapSendingReceiving(sender)
            } else {
                self.sendToken = token
                self.scheduleNewRequesterIfAvailable()
                self.saveTokenIDs()
            }
        }
        present(selector, animated: true)
    }
    
    override func depositSendToken(_ sender: Any) {
        guard let sendToken else {
            return
        }
        let dataSource = Web3DepositDataSource(
            wallet: wallet,
            assetID: sendToken.assetID,
            symbol: sendToken.symbol
        )
        let deposit = DepositViewController(dataSource: dataSource)
        navigationController?.pushViewController(deposit, animated: true)
    }
    
    override func changeReceiveToken(_ sender: Any) {
        let selector = SwapWeb3TokenSelectorViewController(
            wallet: wallet,
            supportedChainIDs: supportedChainIDs,
            intent: .receive,
            tokens: Array(swappableTokens.values),
            selectedAssetID: receiveToken?.assetID
        )
        selector.onSelected = { token in
            if token.assetID == self.sendToken?.assetID {
                self.swapSendingReceiving(sender)
            } else {
                self.receiveToken = token
                self.scheduleNewRequesterIfAvailable()
                self.saveTokenIDs()
            }
        }
        present(selector, animated: true)
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
                        toAddress: depositDestination,
                        toAddressLabel: nil
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
                            let preview = SwapPreviewViewController(
                                wallet: .common(wallet),
                                operation: .web3(operation),
                                sendToken: quote.sendToken,
                                sendAmount: sendAmount,
                                receiveToken: quote.receiveToken,
                                receiveAmount: receiveAmount,
                                receiver: displayReceiver,
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
    
    override func balancedSwapToken(assetID: String) -> BalancedSwapToken? {
        if let item = Web3TokenDAO.shared.token(walletID: walletID, assetID: assetID),
           supportedChainIDs.contains(item.chainID), // This could be redundant, no token with unsupported chain should exists in db
           let token = BalancedSwapToken(tokenItem: item)
        {
            return token
        } else {
            return nil
        }
    }
    
    override func balancedSwapTokens(
        from swappableTokens: [SwapToken]
    ) -> OrderedDictionary<String, BalancedSwapToken> {
        let ids = swappableTokens.map(\.assetID)
        let availableTokens = Web3TokenDAO.shared.tokens(walletID: walletID, ids: ids)
            .reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
        return swappableTokens.reduce(into: OrderedDictionary()) { result, token in
            guard let chainID = token.chain.chainID, supportedChainIDs.contains(chainID) else {
                return
            }
            result[token.assetID] = if let item = availableTokens[token.assetID] {
                BalancedSwapToken(
                    token: token,
                    balance: item.decimalBalance,
                    usdPrice: item.decimalUSDPrice
                )
            } else {
                BalancedSwapToken(token: token, balance: 0, usdPrice: 0)
            }
        }
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
