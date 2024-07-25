import UIKit
import MixinServices

final class MixinSwapViewController: SwapViewController {
    
    private var sendTokens: [TokenItem]?
    private var sendToken: TokenItem? {
        didSet {
            if let token = sendToken {
                let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
                sendBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
                sendIconView.setIcon(token: token)
                sendSymbolLabel.text = token.symbol
                sendNetworkLabel.text = token.chain?.name
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
                sendNetworkLabel.text = nil
                sendValueLabel.text = nil
            }
        }
    }
    
    private var receiveTokens: [BalancedSwappableToken]?
    private var receiveToken: BalancedSwappableToken? {
        didSet {
            if let token = receiveToken {
                let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
                receiveBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
                receiveIconView.setIcon(token: token.token)
                receiveSymbolLabel.text = token.symbol
                receiveNetworkLabel.text = token.token.chain.name
                receiveValueLabel.text = CurrencyFormatter.localizedString(
                    from: token.decimalUSDPrice * token.decimalBalance,
                    format: .fiatMoney,
                    sign: .never,
                    symbol: .currencySymbol
                )
            } else {
                receiveBalanceLabel.text = nil
                receiveIconView.prepareForReuse()
                receiveIconView.image = nil
                receiveSymbolLabel.text = R.string.localizable.select_token()
                receiveNetworkLabel.text = nil
                receiveValueLabel.text = nil
            }
        }
    }
    
    private var receiveAmount: Decimal?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: Unhide swap button and implement the function
        swapBackgroundView.isHidden = true
        swapButton.isHidden = true
        
        reloadTokens()
    }
    
    override func sendAmountEditingChanged(_ sender: UITextField) {
        guard
            let text = sender.text,
            let sendAmount = Decimal(string: text),
            let sendToken
        else {
            return
        }
        reviewButton.isEnabled = sendAmount > 0
            && sendAmount <= sendToken.decimalBalance
            && receiveToken != nil
        updateReceivingAmount()
    }
    
    override func changeSendToken(_ sender: Any) {
        guard let sendTokens else {
            return
        }
        let selector = Web3TransferTokenSelectorViewController<TokenItem>()
        selector.onSelected = { token in
            self.sendToken = token
            self.updateReceivingAmount()
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
            self.receiveToken = token
            self.updateReceivingAmount()
        }
        selector.reload(tokens: receiveTokens)
        present(selector, animated: true)
    }
    
    override func swapSendingReceiving(_ sender: Any) {
        
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
        DispatchQueue.global().async {
            let swappableTokens: [SwappableToken] = swappableTokens.compactMap { token in
                // In case API returns invalid results
                switch token.source {
                case .exin:
                    token
                case .other:
                    nil
                }
            }
            let swappableAssetIDs: [String] = swappableTokens.map(\.assetID)
            let positiveBalancedTokens = TokenDAO.shared.positiveBalancedTokens(assetIDs: swappableAssetIDs)
            let sendTokens = positiveBalancedTokens.filter { $0.decimalBalance > 0 }
            let sendToken = sendTokens.first
            let mapping = positiveBalancedTokens.reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
            let receiveTokens = swappableTokens.map { token in
                if let item = mapping[token.assetID] {
                    BalancedSwappableToken(token: token, balance: item.decimalBalance, usdPrice: item.decimalUSDPrice)
                } else {
                    BalancedSwappableToken(token: token, balance: 0, usdPrice: 0)
                }
            }
            let receiveToken = receiveTokens.first { token in
                token.token.assetID != sendToken?.assetID
            }
            DispatchQueue.main.async {
                self.sendTokens = sendTokens
                self.sendToken = sendToken
                self.receiveTokens = receiveTokens
                self.receiveToken = receiveToken
                self.sendLoadingIndicator.stopAnimating()
                self.receiveLoadingIndicator.stopAnimating()
            }
        }
    }
    
    private func updateReceivingAmount() {
        receiveAmountTextField.text = nil
        reportAdditionalInfo(style: .info, text: R.string.localizable.calculating())
        reviewButton.isEnabled = false
        guard
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text),
            let sendToken,
            let receiveToken
        else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard self?.sendAmountTextField.text == text else {
                return
            }
            let request = QuoteRequest.exin(pay: sendToken, payAmount: sendAmount, receive: receiveToken.token, slippage: 0.01)
            RouteAPI.quote(request: request) { result in
                switch result {
                case .success(let response):
                    guard
                        let self,
                        self.sendAmountTextField.text == text,
                        self.receiveToken?.token.assetID == receiveToken.token.assetID,
                        let receiveAmount = Decimal(string: response.outAmount, locale: .enUSPOSIX)
                    else {
                        return
                    }
                    self.receiveAmount = receiveAmount
                    self.receiveAmountTextField.text = CurrencyFormatter.localizedString(from: receiveAmount as Decimal, format: .precision, sign: .never)
                    let price = CurrencyFormatter.localizedString(from: receiveAmount / sendAmount, format: .precision, sign: .never)
                    self.reportAdditionalInfo(style: .info, text: "1 \(sendToken.symbol) ≈ \(price) \(receiveToken.symbol)")
                    self.reviewButton.isEnabled = true
                case .failure(let error):
                    Logger.general.debug(category: "Web3Swap", message: error.localizedDescription)
                    self?.reportAdditionalInfo(style: .error, text: R.string.localizable.no_quote())
                }
            }
        }
    }
    
}
