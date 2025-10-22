import UIKit
import OrderedCollections
import MixinServices

class SwapViewController: KeyboardBasedLayoutViewController {
    
    enum AdditionalInfoStyle {
        case info
        case error
    }
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var sendStackView: UIStackView!
    
    @IBOutlet weak var sendNetworkLabel: UILabel!
    @IBOutlet weak var sendTokenStackView: UIStackView!
    @IBOutlet weak var sendAmountTextField: UITextField!
    @IBOutlet weak var sendLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var sendIconView: BadgeIconView!
    @IBOutlet weak var sendSymbolLabel: UILabel!
    @IBOutlet weak var sendFooterStackView: UIStackView!
    @IBOutlet weak var depositSendTokenButton: BusyButton!
    @IBOutlet weak var sendBalanceButton: UIButton!
    
    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var receiveStackView: UIStackView!
    
    @IBOutlet weak var receiveNetworkLabel: UILabel!
    @IBOutlet weak var receiveTokenStackView: UIStackView!
    @IBOutlet weak var receiveAmountTextField: UITextField!
    @IBOutlet weak var receiveLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var receiveIconView: BadgeIconView!
    @IBOutlet weak var receiveSymbolLabel: UILabel!
    @IBOutlet weak var receiveBalanceLabel: UILabel!
    
    @IBOutlet weak var footerInfoButton: UIButton!
    @IBOutlet weak var footerInfoProgressView: CircularProgressView!
    @IBOutlet weak var footerSpacingView: UIView!
    @IBOutlet weak var swapPriceButton: UIButton!
    
    @IBOutlet weak var swapBackgroundView: UIView!
    @IBOutlet weak var swapButton: UIButton!
    
    @IBOutlet weak var reviewButton: RoundedButton!
    @IBOutlet weak var reviewButtonWrapperBottomConstrait: NSLayoutConstraint!
    
    var sendToken: BalancedSwapToken? {
        didSet {
            if let sendToken {
                self.updateSendView(style: .token(sendToken))
            } else {
                self.updateSendView(style: .selectable)
            }
        }
    }
    
    var receiveToken: BalancedSwapToken? {
        didSet {
            if let receiveToken {
                updateReceiveView(style: .token(receiveToken))
            } else {
                updateReceiveView(style: .selectable)
            }
        }
    }
    
    // Key is asset id
    private(set) var swappableTokens: OrderedDictionary<String, BalancedSwapToken> = [:]
    private(set) var quote: SwapQuote?
    
    private let arbitrarySendAssetID: String?
    private let arbitraryReceiveAssetID: String?
    private let tokenSource: RouteTokenSource
    
    private lazy var userInputSimulationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.roundingMode = .floor
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    private var requester: SwapQuotePeriodicRequester?
    private var amountRange: SwapQuotePeriodicRequester.AmountRange?
    private var priceUnit: SwapQuote.PriceUnit = .send
    
    init(
        tokenSource: RouteTokenSource,
        sendAssetID: String?,
        receiveAssetID: String?
    ) {
        self.arbitrarySendAssetID = sendAssetID
        self.arbitraryReceiveAssetID = receiveAssetID
        self.tokenSource = tokenSource
        let nib = R.nib.swapView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sendView.layer.masksToBounds = true
        sendView.layer.cornerRadius = 8
        sendStackView.setCustomSpacing(0, after: sendTokenStackView)
        let swapInputAccessoryView = R.nib.swapInputAccessoryView(withOwner: nil)!
        sendAmountTextField.inputAccessoryView = swapInputAccessoryView
        swapInputAccessoryView.delegate = self
        sendLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        sendAmountTextField.becomeFirstResponder()
        sendAmountTextField.delegate = self
        
        receiveView.layer.masksToBounds = true
        receiveView.layer.cornerRadius = 8
        receiveStackView.setCustomSpacing(10, after: receiveTokenStackView)
        receiveLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        for symbolLabel in [sendSymbolLabel, receiveSymbolLabel] {
            symbolLabel!.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
        }
        footerInfoButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .regular),
            adjustForContentSize: true
        )
        
        updateSendView(style: .loading)
        updateReceiveView(style: .loading)
        reloadTokens()
        footerInfoButton.addTarget(
            self,
            action: #selector(inputAmountByRange(_:)),
            for: .touchUpInside
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requester?.start(delay: 0)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        requester?.stop()
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.bounds.height - keyboardFrame.origin.y
        reviewButtonWrapperBottomConstrait.constant = keyboardHeight
        view.layoutIfNeeded()
    }
    
    @IBAction func sendAmountEditingChanged(_ sender: Any) {
        amountRange = nil
        scheduleNewRequesterIfAvailable()
    }
    
    @IBAction func changeSendToken(_ sender: Any) {
        
    }
    
    @IBAction func depositSendToken(_ sender: Any) {
        
    }
    
    @IBAction func inputSendTokenBalance(_ sender: Any) {
        inputSendAmount(multiplier: 1)
    }
    
    @IBAction func changeReceiveToken(_ sender: Any) {
        
    }
    
    @IBAction func swapSendingReceiving(_ sender: Any) {
        if let sender = sender as? UIButton, sender === swapButton {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            swapButton.layer.add(animation, forKey: nil)
        }
        swap(&sendToken, &receiveToken)
        scheduleNewRequesterIfAvailable()
        saveTokenIDs()
    }
    
    @IBAction func swapPrice(_ sender: Any) {
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
    
    @IBAction func review(_ sender: RoundedButton) {
        
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "trade_home"])
    }
    
    func prepareForReuse(sender: Any) {
        sendAmountTextField.text = nil
        sendAmountTextField.sendActions(for: .editingChanged)
        reloadTokens() // Update send token balance
    }
    
    func balancedSwapToken(assetID: String) -> BalancedSwapToken? {
        nil
    }
    
    func balancedSwapTokens(
        from swappableTokens: [SwapToken]
    ) -> OrderedDictionary<String, BalancedSwapToken> {
        [:]
    }
    
    func scheduleNewRequesterIfAvailable() {
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
            source: tokenSource
        )
        requester.delegate = self
        self.requester = requester
        requester.start(delay: 1)
    }
    
}

extension SwapViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension SwapViewController: UITextFieldDelegate {
    
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

extension SwapViewController: SwapInputAccessoryView.Delegate {
    
    func swapInputAccessoryView(_ view: SwapInputAccessoryView, didSelectMultiplier multiplier: Decimal) {
        inputSendAmount(multiplier: multiplier)
    }
    
    func swapInputAccessoryViewDidSelectDone(_ view: SwapInputAccessoryView) {
        sendAmountTextField.resignFirstResponder()
    }
    
}

extension SwapViewController: SwapQuotePeriodicRequesterDelegate {
    
    func swapQuotePeriodicRequesterWillUpdate(_ requester: SwapQuotePeriodicRequester) {
        setFooter(.calculating)
        reviewButton.isEnabled = false
    }
    
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didUpdate result: Result<SwapQuote, any Error>) {
        switch result {
        case .success(let quote):
            self.quote = quote
            self.amountRange = nil
            Logger.general.debug(category: "Swap", message: "Got quote: \(quote)")
            receiveAmountTextField.text = CurrencyFormatter.localizedString(
                from: quote.receiveAmount,
                format: .precision,
                sign: .never
            )
            updateCurrentPriceRepresentation(quote: quote)
            footerInfoProgressView.setProgress(1, animationDuration: nil)
            reviewButton.isEnabled = quote.sendAmount > 0
            && quote.sendAmount <= quote.sendToken.decimalBalance
            reporter.report(event: .tradeQuote, tags: ["type": "swap", "result": "success"])
        case .failure(let error):
            let description: String
            let amountRange: SwapQuotePeriodicRequester.AmountRange?
            let reason: String
            switch error {
            case let SwapQuotePeriodicRequester.ResponseError.invalidAmount(range):
                description = range.description
                amountRange = range
                reason = "invalid_amount"
            case MixinAPIResponseError.invalidQuoteAmount:
                description = R.string.localizable.swap_invalid_amount()
                amountRange = nil
                reason = "invalid_amount"
            case MixinAPIResponseError.noAvailableQuote:
                description = R.string.localizable.swap_no_available_quote()
                amountRange = nil
                reason = "no_available_quote"
            case let error as MixinAPIError:
                description = error.localizedDescription
                amountRange = nil
                reason = if error.isClientErrorResponse {
                    "client_error"
                } else if error.isServerErrorResponse {
                    "server_error"
                } else {
                    "other"
                }
            default:
                description = "\(error)"
                amountRange = nil
                reason = "other"
            }
            Logger.general.debug(category: "Swap", message: description)
            setFooter(.error(description))
            self.amountRange = amountRange
            reporter.report(event: .tradeQuote, tags: ["type": "swap", "result": "failure", "reason": reason])
        }
    }
    
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didCountDown value: Int) {
        let progress = Double(value) / Double(requester.refreshInterval)
        Logger.general.debug(category: "Swap", message: "Progress: \(progress)")
        footerInfoProgressView.setProgress(progress, animationDuration: 1)
    }
    
}

extension SwapViewController {
    
    enum TokenSelectorStyle {
        case loading
        case selectable
        case token(BalancedSwapToken)
    }
    
    func updateSendView(style: TokenSelectorStyle) {
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
    
    func updateReceiveView(style: TokenSelectorStyle) {
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
    
}

extension SwapViewController {
    
    enum Footer {
        case calculating
        case error(String)
        case price(String)
    }
    
    func setFooter(_ footer: Footer?) {
        switch footer {
        case .calculating:
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(R.string.localizable.calculating(), for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .error(let description):
            footerInfoButton.setTitleColor(R.color.red(), for: .normal)
            footerInfoButton.setTitle(description, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .price(let price):
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(price, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = false
            footerSpacingView.isHidden = false
            swapPriceButton.isHidden = false
        case nil:
            footerInfoButton.isHidden = true
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        }
        let reviewButtonFrame = reviewButton.convert(reviewButton.bounds, to: view)
        let contentViewFrame = contentView.convert(contentView.bounds, to: view)
        scrollView.alwaysBounceVertical = reviewButtonFrame.intersects(contentViewFrame)
    }
    
}

extension SwapViewController {
    
    struct AssetIDPair {
        let send: String
        let receive: String
    }
    
    static func loadTokenIDs() -> AssetIDPair? {
        let ids = AppGroupUserDefaults.Wallet.swapTokens
        return if ids.count == 2 {
            AssetIDPair(send: ids[0], receive: ids[1])
        } else {
            nil
        }
    }
    
    func saveTokenIDs() {
        guard
            let sendID = sendToken?.assetID,
            let receiveID = receiveToken?.assetID
        else {
            return
        }
        AppGroupUserDefaults.Wallet.swapTokens = [sendID, receiveID]
    }
    
}

extension SwapViewController {
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        guard presentedViewController == nil else {
            return
        }
        sendAmountTextField.becomeFirstResponder()
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        reviewButtonWrapperBottomConstrait.constant = 0
        view.layoutIfNeeded()
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
            sendAmountTextField.sendActions(for: .editingChanged)
        } else if let maximum = amountRange.maximum, sendAmount > maximum {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: maximum as NSDecimalNumber)
            sendAmountTextField.sendActions(for: .editingChanged)
        }
    }
    
    private func reloadTokens() {
        RouteAPI.swappableTokens(source: tokenSource) { [weak self] result in
            switch result {
            case .success(let tokens):
                self?.reloadData(swappableTokens: tokens)
            case .failure(.requiresUpdate):
                self?.reportClientOutdated()
            case .failure(let error):
                Logger.general.debug(category: "Swap", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadTokens()
                }
            }
        }
    }
    
    private func reportClientOutdated() {
        let alert = UIAlertController(
            title: R.string.localizable.update_mixin(),
            message: R.string.localizable.app_update_tips(Bundle.main.shortVersionString),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: R.string.localizable.update(), style: .default, handler: { _ in
            self.navigationController?.popViewController(animated: false)
            UIApplication.shared.open(.mixinMessenger, options: [:], completionHandler: nil)
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.later(), style: .cancel, handler: { _ in
            self.navigationController?.popViewController(animated: true)
        }))
        self.present(alert, animated: true)
    }
    
    private func reloadData(swappableTokens: [SwapToken]) {
        DispatchQueue.global().async { [weak self, arbitrarySendAssetID, arbitraryReceiveAssetID] in
            let lastTokenIDs = Self.loadTokenIDs()
            let tokens = self?.balancedSwapTokens(from: swappableTokens) ?? [:]
            
            let sendToken: BalancedSwapToken?
            if let id = arbitrarySendAssetID ?? lastTokenIDs?.send {
                if let token = tokens[id] {
                    sendToken = token
                } else {
                    sendToken = self?.balancedSwapToken(assetID: id)
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
                    receiveToken = self?.balancedSwapToken(assetID: id)
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
    
    private func updateCurrentPriceRepresentation(quote: SwapQuote) {
        let priceRepresentation = quote.priceRepresentation(unit: priceUnit)
        setFooter(.price(priceRepresentation))
    }
    
    private func inputSendAmount(multiplier: Decimal) {
        guard let sendToken else {
            return
        }
        let amount = sendToken.decimalBalance * multiplier
        if amount >= 0.00000001 {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: amount as NSDecimalNumber)
            sendAmountTextField.sendActions(for: .editingChanged)
        }
    }
    
}
