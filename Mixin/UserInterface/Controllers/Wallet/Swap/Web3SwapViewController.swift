import UIKit
import OrderedCollections
import MixinServices

final class Web3SwapViewController: SwapViewController {
    
    private let wallet: Web3Wallet
    private let supportedChainIDs: Set<String>
    private let slippage: Decimal = 0.01
    
    override var orderWalletID: String? {
        wallet.walletID
    }
    
    private var walletID: String {
        wallet.walletID
    }
    
    init(
        wallet: Web3Wallet,
        mode: Mode,
        sendAssetID: String?,
        receiveAssetID: String?
    ) {
        self.wallet = wallet
        self.supportedChainIDs = Web3AddressDAO.shared.chainIDs(walletID: wallet.walletID)
        super.init(
            mode: mode,
            openOrderRequester: PendingSwapOrderLoader(
                behavior: .watchWallet(id: wallet.walletID)
            ),
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
            mode: .simple,
            openOrderRequester: PendingSwapOrderLoader(
                behavior: .watchWallet(id: wallet.walletID)
            ),
            tokenSource: .web3,
            sendAssetID: sendAssetID,
            receiveAssetID: receiveAssetID
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.trade(),
            wallet: .common(wallet)
        )
        openOrderRequester.delegate = self
    }
    
    override func changeSendToken(_ sender: Any) {
        let selector = SwapWeb3TokenSelectorViewController(
            wallet: wallet,
            supportedChainIDs: supportedChainIDs,
            intent: .send,
            selectedAssetID: sendToken?.assetID
        )
        selector.onSelected = { token in
            if token.assetID == self.receiveToken?.assetID {
                self.swapSendingReceiving()
            } else {
                self.setSendToken(token)
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
            selectedAssetID: receiveToken?.assetID
        )
        selector.onSelected = { token in
            if token.assetID == self.sendToken?.assetID {
                self.swapSendingReceiving()
            } else {
                self.setReceiveToken(token)
            }
        }
        present(selector, animated: true)
    }
    
    override func review(_ sender: RoundedButton) {
        let job = AddBotIfNotFriendJob(userID: BotUserID.mixinRoute)
        ConcurrentJobQueue.shared.addJob(job: job)
        switch mode {
        case .simple:
            reviewSimpleOrder()
        case .advanced:
            reviewAdvancedOrder()
        }
    }
    
    override func showOrders(_ sender: Any) {
        super.showOrders(sender)
        let orders = SwapOrdersViewController(wallet: .common(wallet))
        navigationController?.pushViewController(orders, animated: true)
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
        let prices = MarketDAO.shared.currentPrices(assetIDs: ids)
        return swappableTokens.reduce(into: OrderedDictionary()) { result, token in
            guard let chainID = token.chain.chainID, supportedChainIDs.contains(chainID) else {
                return
            }
            let marketPrice: Decimal? = if let value = prices[token.assetID] {
                Decimal(string: value, locale: .enUSPOSIX)
            } else {
                nil
            }
            result[token.assetID] = if let item = availableTokens[token.assetID] {
                BalancedSwapToken(
                    token: token,
                    balance: item.decimalBalance,
                    usdPrice: marketPrice ?? item.decimalUSDPrice
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
    
    private func reviewSimpleOrder() {
        guard
            let quote,
            let sendToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: quote.sendToken.assetID),
            let sendChain = Web3Chain.chain(chainID: sendToken.chainID),
            let sendingAddress = Web3AddressDAO.shared.address(walletID: walletID, chainID: sendToken.chainID),
            let receiveToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: quote.receiveToken.assetID),
            let receiveAddress = Web3AddressDAO.shared.address(walletID: walletID, chainID: receiveToken.chainID)
        else {
            return
        }
        
        let payment = Web3SendingTokenPayment(
            wallet: wallet,
            chain: sendChain,
            token: sendToken,
            fromAddress: sendingAddress
        )
        let request = SwapRequest(
            walletId: wallet.walletID,
            sendToken: quote.sendToken,
            sendAmount: quote.sendAmount,
            receiveToken: quote.receiveToken,
            source: .web3,
            slippage: slippage,
            payload: quote.payload,
            withdrawalDestination: receiveAddress.destination,
            referral: nil
        )
        reviewButton.isBusy = true
        RouteAPI.swap(request: request) { [weak self] response in
            guard let self else {
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
                    self.reviewButton.isBusy = false
                    return
                }
                let addressPayment = Web3SendingTokenToAddressPayment(
                    payment: payment,
                    toAddress: depositDestination,
                    toAddressLabel: nil
                )
                Task {
                    await self.presentPreview(
                        mode: .simple,
                        displayReceiverUserID: response.displayUserId,
                        payment: addressPayment,
                        sendAmount: sendAmount,
                        receiveToken: receiveToken,
                        receiveAmount: receiveAmount
                    )
                }
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                reviewButton.isBusy = false
            }
        }
        reporter.report(event: .tradePreview)
    }
    
    private func reviewAdvancedOrder() {
        guard
            let sendAssetID = sendToken?.assetID,
            let sendToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: sendAssetID),
            let sendChain: Web3Chain = .chain(chainID: sendToken.chainID),
            let sendAmount = pricingModel.sendAmount,
            let sendTokenAddress = Web3AddressDAO.shared.address(walletID: walletID, chainID: sendToken.chainID),
            let receiveAssetID = receiveToken?.assetID,
            let receiveToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: receiveAssetID),
            let receiveAmount = pricingModel.receiveAmount,
            let receiveTokenAddress = Web3AddressDAO.shared.address(walletID: walletID, chainID: receiveToken.chainID)
        else {
            return
        }
        reviewButton.isBusy = true
        let payment = Web3SendingTokenPayment(
            wallet: wallet,
            chain: sendChain,
            token: sendToken,
            fromAddress: sendTokenAddress
        )
        let request = Web3LimitOrderRequest(
            walletID: walletID,
            assetID: sendToken.assetID,
            amount: sendAmount,
            assetDestination: sendTokenAddress.destination,
            receiveAssetID: receiveToken.assetID,
            expectedReceiveAmount: receiveAmount,
            receiveAssetDestination: receiveTokenAddress.destination,
            expireAt: selectedExpiry.date
        )
        RouteAPI.createLimitOrder(request: request) { [selectedExpiry, weak self] result in
            switch result {
            case let .success(response):
                let addressPayment = Web3SendingTokenToAddressPayment(
                    payment: payment,
                    toAddress: response.depositDestination,
                    toAddressLabel: nil
                )
                Task {
                    await self?.presentPreview(
                        mode: .advanced(selectedExpiry),
                        displayReceiverUserID: response.displayUserID,
                        payment: addressPayment,
                        sendAmount: sendAmount,
                        receiveToken: receiveToken,
                        receiveAmount: receiveAmount
                    )
                }
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.reviewButton.isBusy = false
            }
        }
        reporter.report(event: .tradePreview)
    }
    
    private func presentPreview(
        mode: Payment.SwapContext.Mode,
        displayReceiverUserID: String,
        payment: Web3SendingTokenToAddressPayment,
        sendAmount: Decimal,
        receiveToken: Web3TokenItem,
        receiveAmount: Decimal,
    ) async {
        do {
            let displayReceiver: UserItem
            if let user = UserDAO.shared.getUser(userId: displayReceiverUserID) {
                displayReceiver = user
            } else {
                let response = try await UserAPI.user(userID: displayReceiverUserID)
                UserDAO.shared.updateUsers(users: [response])
                displayReceiver = UserItem.createUser(from: response)
            }
            
            let operation = switch payment.chain.specification {
            case .evm(let id):
                try EVMTransferToAddressOperation(
                    evmChainID: id,
                    payment: payment,
                    decimalAmount: sendAmount
                )
            case .solana:
                try SolanaTransferToAddressOperation(
                    payment: payment,
                    decimalAmount: sendAmount
                )
            }
            
            let fee = try await operation.loadFee()
            let sendRequirement = BalanceRequirement(token: payment.token, amount: sendAmount)
            let feeRequirement = BalanceRequirement(token: operation.feeToken, amount: fee.tokenAmount)
            let requirements = sendRequirement.merging(with: feeRequirement)
            let isBalanceSufficient = requirements.allSatisfy(\.isSufficient)
            
            await MainActor.run {
                guard let homeContainer = UIApplication.homeContainerViewController else {
                    return
                }
                guard isBalanceSufficient else {
                    reviewButton.isBusy = false
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
                    mode: mode,
                    operation: .web3(operation),
                    sendToken: payment.token,
                    sendAmount: sendAmount,
                    receiveToken: receiveToken,
                    receiveAmount: receiveAmount,
                    receiver: displayReceiver,
                    warnings: []
                )
                preview.onDismiss = { [weak self] in
                    self?.reviewButton.isBusy = false
                }
                homeContainer.present(preview, animated: true)
            }
        } catch {
            await MainActor.run {
                showAutoHiddenHud(style: .error, text: "\(error)")
                self.reviewButton.isBusy = false
            }
        }
    }
    
}

extension Web3SwapViewController: PendingSwapOrderLoader.Delegate {
    
    func pendingSwapOrder(_ loader: PendingSwapOrderLoader, didLoad orders: [SwapOrder]) {
        let tokens = Web3OrderDAO.shared.swapOrderTokens(orders: orders)
        let viewModels = orders.map { order in
            SwapOrderViewModel(
                order: order,
                wallet: .common(wallet),
                payToken: tokens[order.payAssetID],
                receiveToken: tokens[order.receiveAssetID]
            )
        }
        DispatchQueue.main.async {
            self.reload(openOrders: viewModels)
        }
    }
    
}
