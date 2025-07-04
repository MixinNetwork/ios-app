import UIKit
import OrderedCollections
import Alamofire
import MixinServices

class MixinSwapViewController: SwapViewController {
    
    private let arbitrarySendAssetID: String?
    private let arbitraryReceiveAssetID: String?
    private let referral: String?
    
    // Key is asset id
    fileprivate(set) var swappableTokens: OrderedDictionary<String, BalancedSwapToken> = [:]
    
    fileprivate(set) var sendToken: BalancedSwapToken? {
        didSet {
            if let sendToken {
                self.updateSendView(style: .token(sendToken))
            } else {
                self.updateSendView(style: .selectable)
            }
            depositTokenRequest?.cancel()
        }
    }
    
    fileprivate(set) var receiveToken: BalancedSwapToken? {
        didSet {
            if let receiveToken {
                updateReceiveView(style: .token(receiveToken))
            } else {
                updateReceiveView(style: .selectable)
            }
        }
    }
    
    fileprivate(set) var quote: SwapQuote?
    private var requester: SwapQuotePeriodicRequester?
    private var amountRange: SwapQuotePeriodicRequester.AmountRange?
    
    private var priceUnit: SwapQuote.PriceUnit = .send
    
    private weak var showOrdersItem: BadgeBarButtonItem?
    private weak var depositTokenRequest: Request?
    
    var source: RouteTokenSource {
        .mixin
    }
    
    private lazy var userInputSimulationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.roundingMode = .floor
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    init(sendAssetID: String?, receiveAssetID: String?, referral: String?) {
        self.arbitrarySendAssetID = sendAssetID
        self.arbitraryReceiveAssetID = receiveAssetID
        self.referral = referral
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initTitleBar()
        updateSendView(style: .loading)
        updateReceiveView(style: .loading)
        reloadTokens()
        sendAmountTextField.delegate = self
        footerInfoButton.addTarget(
            self,
            action: #selector(inputAmountByRange(_:)),
            for: .touchUpInside
        )
    }
    
    func initTitleBar() {
        navigationItem.titleView = NavigationTitleView(
            title: R.string.localizable.swap(),
            subtitle: R.string.localizable.privacy_wallet()
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requester?.start(delay: 0)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        requester?.stop()
    }
    
    override func sendAmountEditingChanged(_ sender: Any) {
        amountRange = nil
        scheduleNewRequesterIfAvailable()
    }
    
    override func changeSendToken(_ sender: Any) {
        let selector = getTokenSelectorViewController(recent: .send)
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
    
    func getTokenSelectorViewController(recent: SwapTokenSelectorViewController.Recent) -> SwapTokenSelectorViewController {
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
        
        return SwapTokenSelectorViewController(
            recent: recent,
            tokens: tokens,
            selectedAssetID: selectedAssetID
        )
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
        let selector = getTokenSelectorViewController(recent: .receive)
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
    
    override func swapSendingReceiving(_ sender: Any) {
        super.swapSendingReceiving(sender)
        (sendToken, receiveToken) = (receiveToken, sendToken)
        scheduleNewRequesterIfAvailable()
        saveTokenIDs()
    }
    
    override func swapPrice(_ sender: Any) {
        priceUnit = switch priceUnit {
        case .send:
                .receive
        case .receive:
                .send
        }
        if let quote {
            updateCurrentPriceRepresentation(quote: quote)
        }
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
    
    override func prepareForReuse(sender: Any) {
        super.prepareForReuse(sender: sender)
        reloadTokens() // Update send token balance
    }
    
    override func inputSendAmount(multiplier: Decimal) {
        guard let sendToken else {
            return
        }
        let amount = sendToken.decimalBalance * multiplier
        if amount >= 0.00000001 {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: amount as NSDecimalNumber)
            sendAmountEditingChanged(self)
        }
    }
    
    @objc private func showOrders(_ sender: Any) {
        showOrdersItem?.showBadge = false
        let orders = SwapOrderTableViewController()
        navigationController?.pushViewController(orders, animated: true)
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "trade_home"])
    }
    
    @objc private func inputAmountByRange(_ sender: Any) {
        guard
            let amountRange,
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text, locale: .current)
        else {
            return
        }
        if let minimum = amountRange.minimum, sendAmount < minimum {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: minimum as NSDecimalNumber)
            sendAmountEditingChanged(self)
        } else if let maximum = amountRange.maximum, sendAmount > maximum {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: maximum as NSDecimalNumber)
            sendAmountEditingChanged(self)
        }
    }
    
    func fetchBalancedSwapToken(assetID: String) -> BalancedSwapToken? {
        if let item = TokenDAO.shared.tokenItem(assetID: assetID), let token = BalancedSwapToken(tokenItem: item) {
            return token
        } else if case let .success(token) = SafeAPI.assets(id: assetID), let chain = ChainDAO.shared.chain(chainId: token.chainID) {
            let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
            return BalancedSwapToken(tokenItem: item)
        } else {
            return nil
        }
    }
    
    func fillSwappableTokenBalance(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        BalancedSwapToken.fillMixinBalance(swappableTokens: swappableTokens)
    }
}

extension MixinSwapViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension MixinSwapViewController: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let newText = ((textField.text ?? "") as NSString)
            .replacingCharacters(in: range, with: string)
        if newText.isEmpty {
            return true
        }
        let components = newText.components(separatedBy: currentDecimalSeparator)
        switch components.count {
        case 1:
            return true
        case 2:
            return components[1].count <= 8
        default:
            return false
        }
    }
    
}

extension MixinSwapViewController: SwapQuotePeriodicRequesterDelegate {
    
    func swapQuotePeriodicRequesterWillUpdate(_ requester: SwapQuotePeriodicRequester) {
        setFooter(.calculating)
        reviewButton.isEnabled = false
    }
    
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didUpdate result: Result<SwapQuote, any Error>) {
        switch result {
        case .success(let quote):
            self.quote = quote
            self.amountRange = nil
            Logger.general.debug(category: "MixinSwap", message: "Got quote: \(quote)")
            receiveAmountTextField.text = CurrencyFormatter.localizedString(
                from: quote.receiveAmount,
                format: .precision,
                sign: .never
            )
            updateCurrentPriceRepresentation(quote: quote)
            footerInfoProgressView.setProgress(1, animationDuration: nil)
            reviewButton.isEnabled = quote.sendAmount > 0
                && quote.sendAmount <= quote.sendToken.decimalBalance
            reporter.report(event: .tradeQuote, tags: ["result": "success", "type": "swap"])
        case .failure(let error):
            let description: String
            let amountRange: SwapQuotePeriodicRequester.AmountRange?
            switch error {
            case let SwapQuotePeriodicRequester.ResponseError.invalidAmount(range):
                description = range.description
                amountRange = range
            case MixinAPIResponseError.invalidQuoteAmount:
                description = R.string.localizable.swap_invalid_amount()
                amountRange = nil
            case MixinAPIResponseError.noAvailableQuote:
                description = R.string.localizable.swap_no_available_quote()
                amountRange = nil
            case let error as MixinAPIError:
                description = error.localizedDescription
                amountRange = nil
            default:
                description = "\(error)"
                amountRange = nil
            }
            Logger.general.debug(category: "MixinSwap", message: description)
            setFooter(.error(description))
            self.amountRange = amountRange
            reporter.report(event: .tradeQuote, tags: ["result": "failure", "type": "swap"])
        }
    }
    
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didCountDown value: Int) {
        let progress = Double(value) / Double(requester.refreshInterval)
        Logger.general.debug(category: "MixinSwap", message: "Progress: \(progress)")
        footerInfoProgressView.setProgress(progress, animationDuration: 1)
    }
    
}

extension MixinSwapViewController {
    
    private enum TokenSelectorStyle {
        case loading
        case selectable
        case token(BalancedSwapToken)
    }
    
    private func reloadTokens() {
        RouteAPI.swappableTokens(source: source) { [weak self] result in
            switch result {
            case .success(let tokens):
                self?.reloadData(swappableTokens: tokens)
            case .failure(.requiresUpdate):
                self?.reportClientOutdated()
            case .failure(let error):
                Logger.general.debug(category: "MixinSwap", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadTokens()
                }
            }
        }
    }
    
    private func reloadData(swappableTokens: [SwapToken]) {
        DispatchQueue.global().async { [weak self, arbitrarySendAssetID, arbitraryReceiveAssetID] in
            let lastTokenIDs = Self.loadTokenIDs()
            let tokens: OrderedDictionary<String, BalancedSwapToken> = (self?.fillSwappableTokenBalance(swappableTokens: swappableTokens) ?? [])
                .reduce(into: OrderedDictionary()) { result, token in
                    result[token.assetID] = token
                }
            
            let sendToken: BalancedSwapToken?
            if let id = arbitrarySendAssetID ?? lastTokenIDs?.send {
                if let token = tokens[id] {
                    sendToken = token
                } else {
                    sendToken = self?.fetchBalancedSwapToken(assetID: id)
                }
            } else {
                sendToken = tokens.values.first { token in
                    token.assetID != arbitraryReceiveAssetID
                }
            }
            
            let receiveToken: BalancedSwapToken?
            if let id = arbitraryReceiveAssetID ?? lastTokenIDs?.receive {
                if id == sendToken?.assetID {
                    receiveToken = nil
                } else if let token = tokens[id] {
                    receiveToken = token
                } else {
                    receiveToken = self?.fetchBalancedSwapToken(assetID: id)
                }
            } else {
                receiveToken = tokens.values.first { token in
                    token.assetID != sendToken?.assetID
                }
            }
            
            let missingAssetID: String?
            if let id = arbitrarySendAssetID, id == arbitraryReceiveAssetID {
                missingAssetID = nil
            } else if let id = arbitrarySendAssetID, sendToken?.assetID != id {
                missingAssetID = id
            } else if let id = arbitraryReceiveAssetID, receiveToken?.assetID != id {
                missingAssetID = id
            } else {
                missingAssetID = nil
            }
            let missingAssetSymbol: String? = if let missingAssetID {
                TokenDAO.shared.symbol(assetID: missingAssetID)
            } else {
                nil
            }
            
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.swappableTokens = tokens
                self.sendToken = sendToken
                self.receiveToken = receiveToken
                if let missingAssetSymbol {
                    let description = R.string.localizable.swap_not_supported(missingAssetSymbol)
                    self.setFooter(.error(description))
                }
            }
        }
    }
    
    private func updateSendView(style: TokenSelectorStyle) {
        UIView.performWithoutAnimation {
            switch style {
            case .loading:
                sendTokenStackView.alpha = 0
                sendIconView.isHidden = false
                sendNetworkLabel.text = "Placeholder"
                sendNetworkLabel.alpha = 0 // Keeps the height
                depositSendTokenButton.isHidden = true
                sendBalanceButton.setTitle("0", for: .normal)
                sendBalanceButton.alpha = 0
                sendBalanceButton.layoutIfNeeded()
                sendLoadingIndicator.startAnimating()
            case .selectable:
                sendTokenStackView.alpha = 1
                sendIconView.isHidden = true
                sendIconView.prepareForReuse()
                sendSymbolLabel.text = R.string.localizable.select_token()
                sendNetworkLabel.text = "Placeholder"
                sendNetworkLabel.alpha = 0 // Keeps the height
                depositSendTokenButton.isHidden = true
                sendBalanceButton.setTitle("0", for: .normal)
                sendBalanceButton.alpha = 0
                sendBalanceButton.layoutIfNeeded()
                sendLoadingIndicator.stopAnimating()
            case .token(let token):
                sendTokenStackView.alpha = 1
                let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
                sendIconView.isHidden = false
                sendIconView.setIcon(swappableToken: token)
                sendSymbolLabel.text = token.symbol
                sendNetworkLabel.text = token.chain.name
                sendNetworkLabel.alpha = 1
                depositSendTokenButton.isHidden = token.decimalBalance != 0
                sendBalanceButton.setTitle(R.string.localizable.balance_abbreviation(balance), for: .normal)
                sendBalanceButton.alpha = 1
                sendBalanceButton.layoutIfNeeded()
                sendLoadingIndicator.stopAnimating()
            }
        }
    }
    
    private func updateReceiveView(style: TokenSelectorStyle) {
        switch style {
        case .loading:
            receiveTokenStackView.alpha = 0
            receiveIconView.isHidden = false
            receiveNetworkLabel.text = "0"
            receiveNetworkLabel.alpha = 0
            receiveBalanceLabel.text = "0"
            receiveBalanceLabel.alpha = 0
            receiveLoadingIndicator.startAnimating()
        case .selectable:
            receiveTokenStackView.alpha = 1
            receiveIconView.isHidden = true
            receiveIconView.prepareForReuse()
            receiveSymbolLabel.text = R.string.localizable.select_token()
            receiveNetworkLabel.text = "0"
            receiveNetworkLabel.alpha = 0
            receiveBalanceLabel.text = "0"
            receiveBalanceLabel.alpha = 0
            receiveLoadingIndicator.stopAnimating()
        case .token(let token):
            receiveTokenStackView.alpha = 1
            let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            receiveIconView.isHidden = false
            receiveIconView.setIcon(swappableToken: token)
            receiveSymbolLabel.text = token.symbol
            receiveNetworkLabel.text = token.chain.name
            receiveNetworkLabel.alpha = 1
            receiveBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
            receiveBalanceLabel.alpha = 1
            receiveLoadingIndicator.stopAnimating()
        }
    }
    
    private func updateCurrentPriceRepresentation(quote: SwapQuote) {
        let priceRepresentation = quote.priceRepresentation(unit: priceUnit)
        setFooter(.price(priceRepresentation))
    }
    
    private func scheduleNewRequesterIfAvailable() {
        receiveAmountTextField.text = nil
        quote = nil
        reviewButton.isEnabled = false
        requester?.stop()
        requester = nil
        guard
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text, locale: .current),
            sendAmount > 0,
            let sendToken,
            let receiveToken
        else {
            setFooter(nil)
            reviewButton.setTitle(R.string.localizable.review(), for: .normal)
            return
        }
        if sendAmount > sendToken.decimalBalance {
            reviewButton.setTitle(R.string.localizable.insufficient_balance(), for: .normal)
        } else {
            reviewButton.setTitle(R.string.localizable.review(), for: .normal)
        }
        setFooter(.calculating)
        let requester = SwapQuotePeriodicRequester(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken,
            slippage: 0.01,
            source: source
        )
        requester.delegate = self
        self.requester = requester
        requester.start(delay: 1)
    }
    
}

extension MixinSwapViewController {
    
    private struct AssetIDPair {
        let send: String
        let receive: String
    }
    
    private static func loadTokenIDs() -> AssetIDPair? {
        let ids = AppGroupUserDefaults.Wallet.swapTokens
        return if ids.count == 2 {
            AssetIDPair(send: ids[0], receive: ids[1])
        } else {
            nil
        }
    }
    
    private func saveTokenIDs() {
        guard
            let sendID = sendToken?.assetID,
            let receiveID = receiveToken?.assetID
        else {
            return
        }
        AppGroupUserDefaults.Wallet.swapTokens = [sendID, receiveID]
    }
    
}
