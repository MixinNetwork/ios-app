import UIKit
import MixinServices

final class Web3SwapViewController: SwapViewController {
    
    private let address: String
    private let addressTokens: [Web3Token]
    
    private var sendTokens: [Web3Token]?
    private var sendToken: Web3Token?
    private var receiveTokens: [BalancedSwapToken]?
    private var receiveToken: BalancedSwapToken?
    
    init(address: String, tokens: [Web3Token]) {
        self.address = address
        self.addressTokens = tokens
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.swap()
        
        // TODO: Unhide swap button and implement the function
        swapBackgroundView.isHidden = true
        swapButton.isHidden = true
        
        reloadTokens()
    }
    
    override func sendAmountEditingChanged(_ sender: Any) {
        
    }
    
    override func changeSendToken(_ sender: Any) {
        guard let sendTokens else {
            return
        }
        let selector = Web3TransferTokenSelectorViewController<Web3Token>()
        selector.onSelected = { token in
            self.sendToken = token
            self.reloadSendView(with: token)
            self.updateReceivingAmount()
        }
        selector.reload(tokens: sendTokens)
        present(selector, animated: true)
    }
    
    override func changeReceiveToken(_ sender: Any) {
        guard let receiveTokens else {
            return
        }
        let selectableReceiveTokens = receiveTokens.filter { token in
            if let sendToken {
                !token.isEqual(to: sendToken)
            } else {
                true
            }
        }
        let selector = Web3TransferTokenSelectorViewController<BalancedSwapToken>()
        selector.onSelected = { token in
            self.receiveToken = token
            self.reloadReceiveView(with: token)
            self.updateReceivingAmount()
        }
        selector.reload(tokens: selectableReceiveTokens)
        present(selector, animated: true)
    }
    
    override func review(_ sender: RoundedButton) {
        guard
            let sendToken,
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text),
            let receiveToken,
            let request = SwapRequest.web3(
                sendToken: sendToken,
                sendAmount: sendAmount,
                sendAddress: address,
                receiveToken: receiveToken,
                source: .solana,
                slippage: 0.01
            ) // Review if web3 swapping needs `payload` too
        else {
            return
        }
        sender.isBusy = true
        RouteAPI.swap(request: request) { [weak self] response in
            guard let self else {
                return
            }
            sender.isBusy = false
            switch response {
            case .success(let response):
                self.requestSign(transaction: response.tx)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    private func reloadTokens() {
        RouteAPI.swappableTokens(source: .solana) { [weak self] result in
            switch result {
            case .success(let tokens):
                self?.reloadData(supportedTokens: tokens)
            case .failure(.requiresUpdate):
                self?.reportClientOutdated()
            case .failure(let error):
                Logger.general.debug(category: "Web3Swap", message: error.localizedDescription)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadTokens()
                }
            }
        }
    }
    
    private func reloadData(supportedTokens: [SwapToken]) {
        DispatchQueue.global().async { [addressTokens, weak self] in
            let sendTokens = addressTokens.filter { addressToken in
                supportedTokens.contains { supportedToken in
                    supportedToken.isEqual(to: addressToken)
                }
            }
            let sendToken = sendTokens.first
            let receiveTokens = supportedTokens.map { supportedToken in
                let addressToken = addressTokens.first { addressToken in
                    supportedToken.isEqual(to: addressToken)
                }
                return if let addressToken {
                    BalancedSwapToken(token: supportedToken,
                                           balance: addressToken.decimalBalance,
                                           usdPrice: addressToken.decimalUSDPrice)
                } else {
                    BalancedSwapToken(token: supportedToken,
                                           balance: 0,
                                           usdPrice: 0)
                }
            }
            let receiveToken = receiveTokens.first { token in
                if let sendToken {
                    token.isEqual(to: sendToken)
                } else {
                    true
                }
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.sendTokens = sendTokens
                self.sendToken = sendToken
                self.receiveTokens = receiveTokens
                self.receiveToken = receiveToken
                if let sendToken {
                    self.reloadSendView(with: sendToken)
                }
                if let receiveToken {
                    self.reloadReceiveView(with: receiveToken)
                }
            }
        }
    }
    
    private func updateReceivingAmount() {
        receiveAmountTextField.text = nil
        guard
            let text = sendAmountTextField.text,
            let payAmount = Decimal(string: text),
            let sendToken,
            let receiveToken
        else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard self?.sendAmountTextField.text == text else {
                return
            }
            guard let request = QuoteRequest.web3(
                sendToken: sendToken,
                sendAmount: payAmount,
                receiveToken: receiveToken,
                slippage: 0.01
            ) else {
                self?.receiveAmountTextField.text = nil
                return
            }
            RouteAPI.quote(request: request) { result in
                switch result {
                case .success(let response):
                    guard
                        let self,
                        self.sendAmountTextField.text == text,
                        self.receiveToken?.address == receiveToken.address,
                        let receiveAmount = Decimal(string: response.outAmount, locale: .enUSPOSIX),
                        let decimalAmount = receiveToken.decimalAmount(nativeAmount: receiveAmount)
                    else {
                        return
                    }
                    self.receiveAmountTextField.text = CurrencyFormatter.localizedString(from: decimalAmount as Decimal, format: .precision, sign: .never)
                case .failure(let error):
                    Logger.general.debug(category: "Web3Swap", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func reloadSendView(with token: Web3Token) {
        let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
        sendBalanceButton.setTitle(R.string.localizable.balance_abbreviation(balance), for: .normal)
        sendIconView.setIcon(web3Token: token)
        sendSymbolLabel.text = token.symbol
        sendLoadingIndicator.stopAnimating()
    }
    
    private func reloadReceiveView(with token: BalancedSwapToken) {
        receiveBalanceLabel.text = nil
        receiveIconView.setIcon(swappableToken: token)
        receiveSymbolLabel.text = token.symbol
        receiveLoadingIndicator.stopAnimating()
    }
    
    private func requestSign(transaction raw: String) {
        guard let homeContainer = UIApplication.homeContainerViewController else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: homeContainer.view)
        do {
            guard let transaction = Solana.Transaction(string: raw, encoding: .base64URL) else {
                hud.set(style: .error, text: R.string.localizable.invalid_parameters())
                hud.scheduleAutoHidden()
                return
            }
            let operation = try SolanaTransferWithCustomRespondingOperation(
                transaction: transaction,
                fromAddress: address,
                chain: .solana
            )
            hud.hide()
            let transfer = Web3TransferPreviewViewController(operation: operation, proposer: .web3ToAddress)
            transfer.manipulateNavigationStackOnFinished = true
            Web3PopupCoordinator.enqueue(popup: .request(transfer))
        } catch {
            hud.set(style: .error, text: error.localizedDescription)
            hud.scheduleAutoHidden()
        }
    }
    
}
