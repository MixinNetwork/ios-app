import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class MixinTradeViewController: TradeViewController {
    
    private let referral: String?
    
    private weak var depositTokenRequest: Request?
    
    override var orderWalletID: String {
        myUserId
    }
    
    init(
        mode: Mode,
        sendAssetID: String?,
        receiveAssetID: String?,
        referral: String?
    ) {
        self.referral = referral
        super.init(
            mode: mode,
            tokenSource: .mixin,
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
            wallet: .privacy
        )
    }
    
    override func changeSendToken(_ sender: Any) {
        let selector = TradeMixinTokenSelectorViewController(
            intent: .send,
            selectedAssetID: sendToken?.assetID,
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
        let dataSource = MixinDepositDataSource(
            assetID: sendToken.assetID,
            symbol: sendToken.symbol
        )
        let deposit = DepositViewController(dataSource: dataSource)
        navigationController?.pushViewController(deposit, animated: true)
    }
    
    override func changeReceiveToken(_ sender: Any) {
        let selector = TradeMixinTokenSelectorViewController(
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
        view.endEditing(false)
        let job = AddBotIfNotFriendJob(userID: BotUserID.mixinRoute)
        ConcurrentJobQueue.shared.addJob(job: job)
        switch mode {
        case .simple:
            reviewSimpleOrder(reviewButton: sender)
        case .advanced:
            reviewAdvancedOrder(reviewButton: sender)
        }
    }
    
    override func showOrders(_ sender: Any) {
        super.showOrders(sender)
        let orders = TradeOrdersViewController(wallet: .privacy)
        navigationController?.pushViewController(orders, animated: true)
    }
    
    override func setSendToken(_ sendToken: BalancedSwapToken?) {
        super.setSendToken(sendToken)
        depositTokenRequest?.cancel()
    }
    
    override func balancedSwapToken(assetID: String) -> BalancedSwapToken? {
        if let item = TokenDAO.shared.tokenItem(assetID: assetID), let token = BalancedSwapToken(tokenItem: item) {
            return token
        } else if case let .success(token) = SafeAPI.assets(id: assetID), let chain = ChainDAO.shared.chain(chainId: token.chainID) {
            let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
            return BalancedSwapToken(tokenItem: item)
        } else {
            return nil
        }
    }
    
    override func balancedSwapTokens(
        from swappableTokens: [SwapToken]
    ) -> OrderedDictionary<String, BalancedSwapToken> {
        let ids = swappableTokens.map(\.assetID)
        let availableTokens = TokenDAO.shared.tokenItems(with: ids)
            .reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
        let prices = MarketDAO.shared.currentPrices(assetIDs: ids)
        return swappableTokens.reduce(into: OrderedDictionary()) { result, token in
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
    
    private func reviewSimpleOrder(reviewButton: RoundedButton) {
        guard let quote else {
            return
        }
        reviewButton.isBusy = true
        let request = SwapRequest(
            walletId: nil,
            sendToken: quote.sendToken,
            sendAmount: quote.sendAmount,
            receiveToken: quote.receiveToken,
            source: .mixin,
            slippage: 0.01,
            payload: quote.payload,
            withdrawalDestination: nil,
            referral: referral
        )
        RouteAPI.swap(request: request) { [weak self] response in
            guard self != nil else {
                return
            }
            switch response {
            case .success(let response):
                guard
                    let tx = response.tx,
                    let url = URL(string: tx),
                    quote.sendToken.assetID == response.quote.inputMint,
                    quote.receiveToken.assetID == response.quote.outputMint,
                    let sendAmount = Decimal(string: response.quote.inAmount, locale: .enUSPOSIX),
                    let receiveAmount = Decimal(string: response.quote.outAmount, locale: .enUSPOSIX)
                else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                    reviewButton.isBusy = false
                    return
                }
                let context = Payment.TradeContext(
                    mode: .simple,
                    sendToken: quote.sendToken,
                    sendAmount: sendAmount,
                    receiveToken: quote.receiveToken,
                    receiveAmount: receiveAmount
                )
                let source: UrlWindow.Source = .swap(context: context) { description in
                    if let description {
                        showAutoHiddenHud(style: .error, text: description)
                    }
                    reviewButton.isBusy = false
                }
                _ = UrlWindow.checkUrl(url: url, from: source)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                reviewButton.isBusy = false
            }
        }
        reporter.report(event: .tradePreview)
    }
    
    private func reviewAdvancedOrder(reviewButton: RoundedButton) {
        guard
            let sendToken,
            let sendAmount = pricingModel.sendAmount,
            let receiveToken,
            let receiveAmount = pricingModel.receiveAmount
        else {
            return
        }
        reviewButton.isBusy = true
        let request = MixinLimitOrderRequest(
            walletID: myUserId,
            assetID: sendToken.assetID,
            amount: sendAmount,
            receiveAssetID: receiveToken.assetID,
            expectedReceiveAmount: receiveAmount,
            expireAt: selectedExpiry.date
        )
        RouteAPI.createLimitOrder(request: request) { [selectedExpiry] result in
            switch result {
            case let .success(response):
                guard let url = URL(string: response.tx) else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                    reviewButton.isBusy = false
                    return
                }
                let context = Payment.TradeContext(
                    mode: .advanced(selectedExpiry),
                    sendToken: sendToken,
                    sendAmount: sendAmount,
                    receiveToken: receiveToken,
                    receiveAmount: receiveAmount
                )
                let source: UrlWindow.Source = .swap(context: context) { description in
                    if let description {
                        showAutoHiddenHud(style: .error, text: description)
                    }
                    reviewButton.isBusy = false
                }
                _ = UrlWindow.checkUrl(url: url, from: source)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                reviewButton.isBusy = false
            }
        }
        reporter.report(event: .tradePreview)
    }
    
}

extension MixinTradeViewController: PendingTradeOrderLoader.Delegate {
    
    func pendingSwapOrder(_ loader: PendingTradeOrderLoader, didLoad orders: [TradeOrder]) {
        switch mode {
        case .simple:
            DispatchQueue.main.async(execute: updateOrdersButton)
        case .advanced:
            let tokens = Web3OrderDAO.shared.tradeOrderTokens(orders: orders)
            let viewModels = orders.map { order in
                TradeOrderViewModel(
                    order: order,
                    wallet: .privacy,
                    payToken: tokens[order.payAssetID],
                    receiveToken: tokens[order.receiveAssetID]
                )
            }
            DispatchQueue.main.async {
                self.reload(openOrders: viewModels)
                self.updateOrdersButton()
            }
        }
    }
    
}
