import UIKit
import OrderedCollections
import Alamofire
import MixinServices

class MixinSwapViewController: SwapViewController {
    
    override var sendToken: BalancedSwapToken? {
        didSet {
            depositTokenRequest?.cancel()
        }
    }
    
    private let referral: String?
    
    private weak var showOrdersItem: BadgeBarButtonItem?
    private weak var depositTokenRequest: Request?
    
    init(sendAssetID: String?, receiveAssetID: String?, referral: String?) {
        self.referral = referral
        super.init(
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
        let showOrdersItem = BadgeBarButtonItem(
            image: R.image.ic_title_transaction()!,
            target: self,
            action: #selector(showOrders(_:))
        )
        navigationItem.rightBarButtonItems = [
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            ),
            showOrdersItem,
        ]
        self.showOrdersItem = showOrdersItem
        showOrdersItem.showBadge = !BadgeManager.shared.hasViewed(identifier: .swapOrder)
    }
    
    override func changeSendToken(_ sender: Any) {
        let tokens = swappableTokens.values.sorted {
            $0.sortingValues > $1.sortingValues
        }
        let selector = SwapTokenSelectorViewController(
            recent: .send,
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
        guard let id = sendToken?.assetID else {
            return
        }
        if let item = TokenDAO.shared.tokenItem(assetID: id) {
            let deposit = DepositViewController(token: item)
            navigationController?.pushViewController(deposit, animated: true)
            return
        }
        depositSendTokenButton.isBusy = true
        depositTokenRequest = SafeAPI.asset(id: id, queue: .global()) { [weak self] result in
            DispatchQueue.main.async {
                self?.depositSendTokenButton.isBusy = false
            }
            switch result {
            case .success(let token):
                if let chain = ChainDAO.shared.chain(chainId: token.chainID) {
                    let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                    DispatchQueue.main.async {
                        guard let self, id == self.sendToken?.assetID else {
                            return
                        }
                        let deposit = DepositViewController(token: item)
                        self.navigationController?.pushViewController(deposit, animated: true)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    guard self != nil else {
                        return
                    }
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
    }
    
    override func changeReceiveToken(_ sender: Any) {
        let selector = SwapTokenSelectorViewController(
            recent: .receive,
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
        sender.isBusy = true
        let request = SwapRequest(
            sendToken: quote.sendToken,
            sendAmount: quote.sendAmount,
            receiveToken: quote.receiveToken,
            source: .mixin,
            slippage: 0.01,
            payload: quote.payload,
            withdrawalDestination: nil,
            referral: referral
        )
        let job = AddBotIfNotFriendJob(userID: BotUserID.mixinRoute)
        ConcurrentJobQueue.shared.addJob(job: job)
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
                    sender.isBusy = false
                    return
                }
                let context = Payment.SwapContext(
                    sendToken: quote.sendToken,
                    sendAmount: sendAmount,
                    receiveToken: quote.receiveToken,
                    receiveAmount: receiveAmount
                )
                let source: UrlWindow.Source = .swap(context: context) { description in
                    if let description {
                        showAutoHiddenHud(style: .error, text: description)
                    }
                    sender.isBusy = false
                }
                _ = UrlWindow.checkUrl(url: url, from: source)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                sender.isBusy = false
            }
        }
        reporter.report(event: .tradePreview)
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
        let tokenItems = TokenDAO.shared.tokenItems(with: ids)
        let tokenMaps = tokenItems.reduce(into: [:]) { result, item in
            result[item.assetID] = item
        }
        return swappableTokens.reduce(into: OrderedDictionary()) { result, token in
            result[token.assetID] = if let item = tokenMaps[token.assetID] {
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
    
    @objc private func showOrders(_ sender: Any) {
        showOrdersItem?.showBadge = false
        let orders = SwapOrderTableViewController()
        navigationController?.pushViewController(orders, animated: true)
    }
    
}
