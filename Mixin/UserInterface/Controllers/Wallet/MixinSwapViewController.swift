import UIKit
import Alamofire
import MixinServices

final class MixinSwapViewController: SwapViewController {
    
    // Key is asset id
    private var swappableTokensMap: [String: TokenItem] = [:]
    
    private var sendTokens: [TokenItem]?
    private var sendToken: TokenItem? {
        didSet {
            updateSendView(token: sendToken)
        }
    }
    
    private var receiveTokens: [BalancedSwappableToken]?
    private var receiveToken: BalancedSwappableToken? {
        didSet {
            updateReceiveView(token: receiveToken)
        }
    }
    
    private var receiveAmount: Decimal?
    
    private weak var lastQuoteRequest: Request?
    
    private lazy var userInputSimulationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateSendView(token: nil)
        updateReceiveView(token: nil)
        reloadTokens()
    }
    
    override func sendAmountEditingChanged(_ sender: Any) {
        requestNewQuote()
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
                self.requestNewQuote()
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
                self.requestNewQuote()
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
        self.sendToken = newSendToken
        self.receiveToken = newReceiveToken
        requestNewQuote()
    }
    
    override func review(_ sender: RoundedButton) {
        guard
            let sendToken,
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text),
            let receiveToken,
            let receiveAmount
        else {
            return
        }
        sender.isBusy = true
        let request = SwapRequest.exin(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken.token,
            slippage: 0.01
        )
        RouteAPI.swap(request: request) { [weak self] response in
            guard self != nil else {
                return
            }
            switch response {
            case .success(let response):
                if let url = URL(string: response.tx) {
                    let context = Payment.SwapContext(receiveToken: receiveToken.token, receiveAmount: receiveAmount)
                    let source: UrlWindow.Source = .swap(context: context) { description in
                        if let description {
                            showAutoHiddenHud(style: .error, text: description)
                        }
                        sender.isBusy = false
                    }
                    _ = UrlWindow.checkUrl(url: url, from: source)
                } else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                }
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                sender.isBusy = false
            }
        }
    }
    
    private func reloadTokens() {
        RouteAPI.swappableTokens(source: .exin) { [weak self] result in
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
        DispatchQueue.global().async { [weak self] in
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
            let swappableTokensMap = swappableTokenItems.reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
            
            let sendTokens = swappableAssetIDs.compactMap { id in
                if let token = swappableTokensMap[id], token.decimalBalance > 0 {
                    return token
                } else {
                    return nil
                }
            }
            let sendToken = sendTokens.first
            
            let receiveTokens = swappableTokens.map { token in
                if let item = swappableTokensMap[token.assetID] {
                    return BalancedSwappableToken(token: token, balance: item.decimalBalance, usdPrice: item.decimalUSDPrice)
                } else {
                    // This is not supposed to happen. Missing tokens should be retrieved by API calls
                    Logger.general.warn(category: "MixinSwap", message: "Missing token: \(token.assetID)")
                    return BalancedSwappableToken(token: token, balance: 0, usdPrice: 0)
                }
            }
            let receiveToken = receiveTokens.first { token in
                token.token.assetID != sendToken?.assetID
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
                self.sendLoadingIndicator.stopAnimating()
                self.receiveLoadingIndicator.stopAnimating()
            }
        }
    }
    
    private func updateSendView(token: TokenItem?) {
        if let token {
            let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            sendBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
            sendIconView.setIcon(token: token)
            sendSymbolLabel.text = token.symbol
            if let network = token.chain?.name {
                sendNetworkLabel.text = network
                sendNetworkLabel.alpha = 1
            } else {
                sendNetworkLabel.alpha = 0 // Keeps the height
            }
            sendValueLabel.text = CurrencyFormatter.localizedString(
                from: token.decimalUSDPrice * token.decimalBalance,
                format: .fiatMoney,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            sendBalanceLabel.text = nil
            sendIconView.prepareForReuse()
            sendIconView.image = nil
            sendSymbolLabel.text = R.string.localizable.select_token()
            sendNetworkLabel.alpha = 0 // Keeps the height
            sendValueLabel.text = nil
        }
    }
    
    private func updateReceiveView(token: BalancedSwappableToken?) {
        if let token {
            let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            receiveBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
            receiveIconView.setIcon(token: token.token)
            receiveSymbolLabel.text = token.symbol
            receiveNetworkLabel.text = token.token.chain.name
            receiveNetworkLabel.alpha = 1
        } else {
            receiveBalanceLabel.text = nil
            receiveIconView.prepareForReuse()
            receiveIconView.image = nil
            receiveSymbolLabel.text = R.string.localizable.select_token()
            receiveNetworkLabel.alpha = 0 // Keeps the height
        }
        updateReceiveValueLabel()
    }
    
    private func updateReceiveValueLabel() {
        if let receiveToken, let receiveAmount {
            receiveValueLabel.text = CurrencyFormatter.localizedString(
                from: receiveToken.decimalUSDPrice * receiveAmount,
                format: .fiatMoney,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            receiveValueLabel.text = nil
        }
    }
    
    private func requestNewQuote() {
        receiveAmountTextField.text = nil
        receiveAmount = nil
        updateReceiveValueLabel()
        reviewButton.isEnabled = false
        lastQuoteRequest?.cancel()
        guard
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text),
            let sendToken,
            let receiveToken
        else {
            hideAdditionalInfo()
            return
        }
        showAdditionalInfo(style: .info, text: R.string.localizable.calculating())
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard
                let self,
                self.sendAmountTextField.text == text,
                sendToken.assetID == self.sendToken?.assetID,
                receiveToken.token.assetID == self.receiveToken?.token.assetID
            else {
                return
            }
            let request = QuoteRequest.exin(pay: sendToken, payAmount: sendAmount, receive: receiveToken.token, slippage: 0.01)
            self.lastQuoteRequest = RouteAPI.quote(request: request) { [weak self] result in
                switch result {
                case .success(let response):
                    guard let receiveAmount = Decimal(string: response.outAmount, locale: .enUSPOSIX) else {
                        Logger.general.error(category: "MixinSwap", message: "Invalid receive amount: \(response.outAmount)")
                        return
                    }
                    guard let self else {
                        return
                    }
                    self.receiveAmount = receiveAmount
                    self.receiveAmountTextField.text = CurrencyFormatter.localizedString(from: receiveAmount as Decimal, format: .precision, sign: .never)
                    self.updateReceiveValueLabel()
                    let price = CurrencyFormatter.localizedString(from: receiveAmount / sendAmount, format: .precision, sign: .never)
                    self.showAdditionalInfo(style: .info, text: "1 \(sendToken.symbol) ≈ \(price) \(receiveToken.symbol)")
                    self.reviewButton.isEnabled = sendAmount > 0 && sendAmount <= sendToken.decimalBalance
                case .failure(.httpTransport(.explicitlyCancelled)):
                    break
                case .failure(let error):
                    Logger.general.debug(category: "Web3Swap", message: error.localizedDescription)
                    self?.showAdditionalInfo(style: .error, text: R.string.localizable.swap_no_quote())
                }
            }
        }
    }
    
}
