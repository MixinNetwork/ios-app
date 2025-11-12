import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class MixinSwapViewController: SwapViewController {
    
    override var sendToken: BalancedSwapToken? {
        didSet {
            depositTokenRequest?.cancel()
        }
    }
    
    private let referral: String?
    
    private weak var depositTokenRequest: Request?
    
    init(sendAssetID: String?, receiveAssetID: String?, referral: String?) {
        self.referral = referral
        super.init(
            mode: .simple,
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
            title: R.string.localizable.swap(),
            wallet: .privacy
        )
    }
    
    override func changeSendToken(_ sender: Any) {
        let selector = SwapMixinTokenSelectorViewController(
            intent: .send,
            selectedAssetID: sendToken?.assetID,
        )
        selector.onSelected = { token in
            if token.assetID == self.receiveToken?.assetID {
                self.swapSendingReceiving(sender)
            } else {
                self.sendToken = token
                self.saveTokenIDs()
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
        let selector = SwapMixinTokenSelectorViewController(
            intent: .receive,
            selectedAssetID: receiveToken?.assetID
        )
        selector.onSelected = { token in
            if token.assetID == self.sendToken?.assetID {
                self.swapSendingReceiving(sender)
            } else {
                self.receiveToken = token
                self.saveTokenIDs()
            }
        }
        present(selector, animated: true)
    }
    
    override func review(_ sender: RoundedButton) {
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
        let orders = SwapOrdersViewController(wallet: .privacy)
        navigationController?.pushViewController(orders, animated: true)
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
        return swappableTokens.reduce(into: OrderedDictionary()) { result, token in
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
                let context = Payment.SwapContext(
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
                let context = Payment.SwapContext(
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
