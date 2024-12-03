import UIKit
import Alamofire
import MixinServices

final class MixinSwapViewController: SwapViewController {
    
    private let arbitrarySendAssetID: String?
    private let arbitraryReceiveAssetID: String?
    
    // Key is asset id
    private var swappableTokensMap: [String: TokenItem] = [:]
    
    private var sendTokens: [TokenItem]?
    private var sendToken: TokenItem? {
        didSet {
            if let sendToken {
                self.updateSendView(style: .token(sendToken))
            } else {
                self.updateSendView(style: .selectable)
            }
        }
    }
    
    private var receiveTokens: [BalancedSwappableToken]?
    private var receiveToken: BalancedSwappableToken? {
        didSet {
            if let receiveToken {
                updateReceiveView(style: .token(receiveToken))
            } else {
                updateReceiveView(style: .selectable)
            }
        }
    }
    
    private var quote: SwapQuote?
    private var requester: SwapQuotePeriodicRequester?
    
    private var priceUnit: SwapQuote.PriceUnit = .send
    
    private lazy var userInputSimulationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    init(sendAssetID: String?, receiveAssetID: String?) {
        self.arbitrarySendAssetID = sendAssetID
        self.arbitraryReceiveAssetID = receiveAssetID
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.swap()
        updateSendView(style: .loading)
        updateReceiveView(style: .loading)
        reloadTokens()
        sendAmountTextField.delegate = self
    }
    
    override func sendAmountEditingChanged(_ sender: Any) {
        updateSendValueLabel()
        scheduleNewRequesterIfAvailable()
    }
    
    override func inputMaxSendAmount(_ sender: Any) {
        guard let sendToken else {
            return
        }
        let balance = sendToken.decimalBalance as NSDecimalNumber
        sendAmountTextField.text = userInputSimulationFormatter.string(from: balance)
        sendAmountEditingChanged(sender)
    }
    
    override func changeSendToken(_ sender: Any) {
        guard let sendTokens else {
            return
        }
        let selector = Web3TransferTokenSelectorViewController<TokenItem>()
        selector.onSelected = { token in
            if token.assetID == self.receiveToken?.token.assetID {
                self.swapSendingReceiving(sender)
            } else {
                self.sendToken = token
                self.scheduleNewRequesterIfAvailable()
            }
        }
        selector.reload(tokens: sendTokens)
        present(selector, animated: true)
    }
    
    override func changeReceiveToken(_ sender: Any) {
        guard let receiveTokens else {
            return
        }
        let selector = Web3TransferTokenSelectorViewController<BalancedSwappableToken>()
        selector.onSelected = { token in
            if token.token.assetID == self.sendToken?.assetID {
                self.swapSendingReceiving(sender)
            } else {
                self.receiveToken = token
                self.scheduleNewRequesterIfAvailable()
            }
        }
        selector.reload(tokens: receiveTokens)
        present(selector, animated: true)
    }
    
    override func swapSendingReceiving(_ sender: Any) {
        guard
            let sendToken,
            let receiveToken,
            let newSendToken = swappableTokensMap[receiveToken.token.assetID],
            let newReceiveToken = receiveTokens?.first(where: {
                $0.token.assetID == sendToken.assetID
            })
        else {
            return
        }
        super.swapSendingReceiving(sender)
        self.sendToken = newSendToken
        self.receiveToken = newReceiveToken
        scheduleNewRequesterIfAvailable()
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
        let request = SwapRequest.mixin(
            sendToken: quote.sendToken,
            sendAmount: quote.sendAmount,
            receiveToken: quote.receiveToken,
            source: quote.source,
            slippage: 0.01,
            payload: quote.payload
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
                    let url = URL(string: response.tx),
                    quote.sendToken.assetID == response.quote.inputMint,
                    quote.receiveToken.assetID == response.quote.outputMint,
                    quote.sendAmount == Decimal(string: response.quote.inAmount, locale: .enUSPOSIX),
                    let receiveAmount = Decimal(string: response.quote.outAmount, locale: .enUSPOSIX)
                else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                    sender.isBusy = false
                    return
                }
                let context = Payment.SwapContext(
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
            Logger.general.debug(category: "Web3Swap", message: "Got quote: \(quote)")
            receiveAmountTextField.text = CurrencyFormatter.localizedString(
                from: quote.receiveAmount,
                format: .precision,
                sign: .never
            )
            updateReceiveValueLabel()
            updateCurrentPriceRepresentation(quote: quote)
            footerInfoProgressView.setProgress(1, animationDuration: nil)
            reviewButton.isEnabled = quote.sendAmount > 0
                && quote.sendAmount <= quote.sendToken.decimalBalance
        case .failure(let error):
            let description = switch error {
            case MixinAPIResponseError.invalidQuoteAmount:
                R.string.localizable.swap_invalid_amount()
            case MixinAPIResponseError.noAvailableQuote:
                R.string.localizable.swap_no_available_quote()
            case let error as MixinAPIError:
                error.localizedDescription
            default:
                "\(error)"
            }
            Logger.general.debug(category: "Web3Swap", message: description)
            setFooter(.error(description))
        }
    }
    
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didCountDown value: Int) {
        let progress = Double(value) / Double(requester.refreshInterval)
        Logger.general.debug(category: "Web3Swap", message: "Progress: \(progress)")
        footerInfoProgressView.setProgress(progress, animationDuration: 1)
    }
    
}

extension MixinSwapViewController {
    
    private enum SendTokenSelectorStyle {
        case loading
        case selectable
        case token(TokenItem)
    }
    
    private enum ReceiveTokenSelectorStyle {
        case loading
        case selectable
        case token(BalancedSwappableToken)
    }
    
    private func reloadTokens() {
        RouteAPI.swappableTokens(source: .mixin) { [weak self] result in
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
    
    private func reloadData(swappableTokens: [SwappableToken]) {
        DispatchQueue.global().async { [weak self, arbitrarySendAssetID, arbitraryReceiveAssetID] in
            let swappableAssetIDs: [String] = swappableTokens.map(\.assetID)
            let missingAssetIDs = TokenDAO.shared.inexistAssetIDs(in: swappableAssetIDs)
            if !missingAssetIDs.isEmpty {
                switch SafeAPI.assets(ids: missingAssetIDs) {
                case .success(let tokens):
                    TokenDAO.shared.save(assets: tokens)
                case .failure(let error):
                    Logger.general.error(category: "MixinSwap", message: "\(error)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.reloadData(swappableTokens: swappableTokens)
                    }
                    return
                }
            }
            
            let swappableTokenItems = TokenDAO.shared.tokenItems(with: swappableAssetIDs)
            
            let sendTokens = swappableTokenItems.sorted { (one, another) in
                let left = (one.decimalBalance * one.decimalUSDPrice, one.decimalBalance, one.decimalUSDPrice)
                let right = (another.decimalBalance * another.decimalUSDPrice, another.decimalBalance, another.decimalUSDPrice)
                return left > right
            }
            let sendToken: TokenItem? = if let id = arbitrarySendAssetID {
                sendTokens.first { token in
                    token.assetID == id
                }
            } else {
                sendTokens.first { token in
                    token.assetID != arbitraryReceiveAssetID
                }
            }
            
            let swappableTokensMap = swappableTokenItems.reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
            let receiveTokens = swappableTokens.map { token in
                if let item = swappableTokensMap[token.assetID] {
                    return BalancedSwappableToken(token: token, balance: item.decimalBalance, usdPrice: item.decimalUSDPrice)
                } else {
                    // This is not supposed to happen. Missing tokens should be retrieved by API calls
                    Logger.general.warn(category: "MixinSwap", message: "Missing token: \(token.assetID)")
                    return BalancedSwappableToken(token: token, balance: 0, usdPrice: 0)
                }
            }
            let receiveToken: BalancedSwappableToken? = if let id = arbitraryReceiveAssetID {
                if id == sendToken?.assetID {
                    nil
                } else {
                    receiveTokens.first { token in
                        token.token.assetID == id
                    }
                }
            } else {
                receiveTokens.first { token in
                    token.token.assetID != sendToken?.assetID
                }
            }
            
            let missingAssetID: String?
            if let id = arbitrarySendAssetID, id == arbitraryReceiveAssetID {
                missingAssetID = nil
            } else if let id = arbitrarySendAssetID, sendToken?.assetID != id {
                missingAssetID = id
            } else if let id = arbitraryReceiveAssetID, receiveToken?.token.assetID != id {
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
                self.swappableTokensMap = swappableTokensMap
                self.sendTokens = sendTokens
                self.sendToken = sendToken
                self.receiveTokens = receiveTokens
                self.receiveToken = receiveToken
                if let missingAssetSymbol {
                    let description = R.string.localizable.swap_not_supported(missingAssetSymbol)
                    self.setFooter(.error(description))
                }
            }
        }
    }
    
    private func updateSendView(style: SendTokenSelectorStyle) {
        switch style {
        case .loading:
            sendTokenStackView.alpha = 0
            sendIconView.isHidden = false
            sendLoadingIndicator.startAnimating()
        case .selectable:
            sendTokenStackView.alpha = 1
            sendBalanceLabel.text = nil
            sendIconView.isHidden = true
            sendIconView.prepareForReuse()
            sendIconView.image = nil
            sendSymbolLabel.text = R.string.localizable.select_token()
            sendNetworkLabel.alpha = 0 // Keeps the height
            sendLoadingIndicator.stopAnimating()
        case .token(let token):
            sendTokenStackView.alpha = 1
            let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            sendBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
            sendIconView.isHidden = false
            sendIconView.setIcon(token: token)
            sendSymbolLabel.text = token.symbol
            if let network = token.chain?.name {
                sendNetworkLabel.text = network
                sendNetworkLabel.alpha = 1
            } else {
                sendNetworkLabel.alpha = 0 // Keeps the height
            }
            sendLoadingIndicator.stopAnimating()
        }
        updateSendValueLabel()
    }
    
    private func updateSendValueLabel() {
        guard
            let sendToken,
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text, locale: .current)
        else {
            sendValueLabel.text = nil
            return
        }
        sendValueLabel.text = CurrencyFormatter.localizedString(
            from: sendToken.decimalUSDPrice * sendAmount * Currency.current.decimalRate,
            format: .fiatMoney,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    private func updateReceiveView(style: ReceiveTokenSelectorStyle) {
        switch style {
        case .loading:
            receiveStackView.alpha = 0
            receiveIconView.isHidden = false
            receiveLoadingIndicator.startAnimating()
        case .selectable:
            receiveStackView.alpha = 1
            receiveBalanceLabel.text = nil
            receiveIconView.isHidden = true
            receiveIconView.prepareForReuse()
            receiveIconView.image = nil
            receiveSymbolLabel.text = R.string.localizable.select_token()
            receiveNetworkLabel.alpha = 0 // Keeps the height
            receiveLoadingIndicator.stopAnimating()
        case .token(let token):
            receiveStackView.alpha = 1
            let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            receiveBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
            receiveIconView.isHidden = false
            receiveIconView.setIcon(token: token.token)
            receiveSymbolLabel.text = token.symbol
            receiveNetworkLabel.text = token.token.chain.name
            receiveNetworkLabel.alpha = 1
            receiveLoadingIndicator.stopAnimating()
        }
        updateReceiveValueLabel()
    }
    
    private func updateReceiveValueLabel() {
        guard let receiveToken, let quote else {
            receiveValueLabel.text = nil
            return
        }
        receiveValueLabel.text = CurrencyFormatter.localizedString(
            from: receiveToken.decimalUSDPrice * quote.receiveAmount * Currency.current.decimalRate,
            format: .fiatMoney,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    private func updateCurrentPriceRepresentation(quote: SwapQuote) {
        let priceRepresentation = quote.priceRepresentation(unit: priceUnit)
        setFooter(.price(priceRepresentation))
    }
    
    private func scheduleNewRequesterIfAvailable() {
        receiveAmountTextField.text = nil
        quote = nil
        updateReceiveValueLabel()
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
            receiveToken: receiveToken.token,
            slippage: 0.01
        )
        requester.delegate = self
        self.requester = requester
        requester.start(delay: 1)
    }
    
}
