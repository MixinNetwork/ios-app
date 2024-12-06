import UIKit
import MixinServices

final class TransferOutViewController: KeyboardBasedLayoutViewController {
    
    enum Opponent {
        case contact(UserItem)
        case address(Address)
        case mainnet(String)
    }
    
    private struct Fee {
        let amount: Decimal
        let token: Token
    }
    
    @IBOutlet weak var contentScrollView: UIScrollView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var opponentImageView: AvatarImageView!
    @IBOutlet weak var tokenSelectorView: AssetComboBoxView!
    
    @IBOutlet weak var amountSymbolLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var switchAmountIntentButton: UIButton!
    
    @IBOutlet weak var memoView: CornerView!
    @IBOutlet weak var memoTextField: UITextField!
    
    @IBOutlet weak var withdrawFeeWrapperView: UIView!
    @IBOutlet weak var withdrawFeeView: WithdrawFeeView!
    
    @IBOutlet weak var continueWrapperView: TouchEventBypassView!
    @IBOutlet weak var continueButton: RoundedButton!
    
    @IBOutlet weak var continueWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var symbolLeadingConstraint: NSLayoutConstraint!
    
    private let placeHolderFont = UIFont.preferredFont(forTextStyle: .callout)
    private let amountFont = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
    private let maxMemoDataCount = 200
    private let traceID = UUID().uuidString.lowercased()
    
    private var token: TokenItem?
    private var opponent: Opponent
    private var amountIntent: AmountIntent = .byToken
    
    private var selectableFeeItems: [WithdrawFeeItem]?
    private var selectedFeeItemIndex: Int?
    private var selectedFeeItem: WithdrawFeeItem? {
        if let selectableFeeItems, let selectedFeeItemIndex {
            return selectableFeeItems[selectedFeeItemIndex]
        } else {
            return nil
        }
    }
    
    private var availableTokens = [TokenItem]()
    private var adjustBottomConstraintWhenKeyboardFrameChanges = true
    
    private lazy var balanceInputAccessoryView: BalanceInputAccessoryView = {
        let view = R.nib.balanceInputAccessoryView(withOwner: nil)!
        view.button.addTarget(self, action: #selector(fillBalanceAction(_:)), for: .touchUpInside)
        return view
    }()
    
    init(token: TokenItem?, to opponent: Opponent) {
        self.token = token
        self.opponent = opponent
        let nib = R.nib.transferOutView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tokenSelectorView.button.addTarget(self, action: #selector(switchToken(_:)), for: .touchUpInside)
        withdrawFeeView.switchFeeButton.addTarget(self, action: #selector(switchFeeToken(_:)), for: .touchUpInside)
        continueWrapperView.exception = continueButton
        amountExchangeLabel.text = "0" + currentDecimalSeparator + "00 " + Currency.current.code
        switch opponent {
        case .contact(let user):
            navigationItem.titleView = NavigationTitleView(
                title: user.isCreatedByMessenger ? user.identityNumber : user.userId,
                subtitle: R.string.localizable.send_to(user.fullName)
            )
            navigationItem.rightBarButtonItem = .tintedIcon(
                image: R.image.ic_title_transaction(),
                target: self,
                action: #selector(showTransactionHistory(_:))
            )
            opponentImageView.isHidden = false
            contentStackView.setCustomSpacing(12, after: opponentImageView)
            opponentImageView.setImage(with: user)
            memoView.isHidden = false
            withdrawFeeWrapperView.isHidden = true
        case .address(let address):
            navigationItem.titleView = NavigationTitleView(
                title: R.string.localizable.send_to(address.label),
                subtitle: address.compactRepresentation
            )
            navigationItem.rightBarButtonItem = .tintedIcon(
                image: R.image.ic_title_transaction(),
                target: self,
                action: #selector(showTransactionHistory(_:))
            )
            opponentImageView.isHidden = true
            memoView.isHidden = true
            withdrawFeeWrapperView.isHidden = false
            if let token {
                reloadWithdrawFee(with: token, address: address)
            }
        case .mainnet(let address):
            navigationItem.titleView = NavigationTitleView(
                title: R.string.localizable.send(),
                subtitle: Address.compactRepresentation(of: address)
            )
            opponentImageView.isHidden = true
            memoView.isHidden = true
            withdrawFeeWrapperView.isHidden = false
            withdrawFeeView.networkFeeLabel.text = "0"
            withdrawFeeView.switchFeeDisclosureIndicatorView.isHidden = true
            withdrawFeeView.isUserInteractionEnabled = false
        }
        
        if let token {
            updateViews(token: token)
        } else {
            let center = NotificationCenter.default
            center.addObserver(self,
                               selector: #selector(fetchAvailableAssets),
                               name: TokenDAO.tokensDidChangeNotification,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(fetchAvailableAssets),
                               name: ChainDAO.chainsDidChangeNotification,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(fetchAvailableAssets),
                               name: UTXOService.balanceDidUpdateNotification,
                               object: nil)
            ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
            fetchAvailableAssets()
            let job = SyncOutputsJob()
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        
        amountTextField.adjustsFontForContentSizeCategory = true
        amountTextField.becomeFirstResponder()
        amountTextField.delegate = self
        memoTextField.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func keyboardWillChangeFrame(_ notification: Notification) {
        guard adjustBottomConstraintWhenKeyboardFrameChanges else {
            return
        }
        super.keyboardWillChangeFrame(notification)
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.bounds.height - keyboardFrame.origin.y
        continueWrapperBottomConstraint.constant = keyboardHeight
        contentScrollView.contentInset.bottom = keyboardHeight + continueWrapperView.frame.height
        contentScrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        view.layoutIfNeeded()
        if !viewHasAppeared, ScreenHeight.current <= .short {
            contentScrollView.contentOffset.y = opponentImageView.frame.maxY
        }
    }
    
    @IBAction func amountEditingChanged(_ sender: Any) {
        let amountText = amountTextField.text ?? ""
        amountTextField.font = amountText.isEmpty ? placeHolderFont : amountFont
        guard let token, let amount = Decimal(string: amountText, locale: .current) else {
            switch amountIntent {
            case .byToken:
                amountExchangeLabel.text = "0" + currentDecimalSeparator + "00 " + Currency.current.code
            case .byFiatMoney:
                if let token {
                    amountExchangeLabel.text = "0 " + token.symbol
                    amountExchangeLabel.isHidden = false
                } else {
                    amountExchangeLabel.isHidden = true
                }
            }
            amountSymbolLabel.isHidden = true
            continueButton.isEnabled = false
            return
        }
        
        let fiatMoneyPrice = token.decimalUSDPrice * Decimal(Currency.current.rate)
        switch amountIntent {
        case .byToken:
            let fiatMoneyAmount = amount * fiatMoneyPrice
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencyCode)
            
            if amount == token.decimalBalance {
                hideInputAccessoryView()
            } else if amountText.count >= 4, token.decimalBalance != 0, token.localizedBalance.hasPrefix(amountText) {
                showInputAccessoryView()
            } else {
                hideInputAccessoryView()
            }
        case .byFiatMoney:
            let assetAmount = amount / fiatMoneyPrice
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: assetAmount, format: .pretty, sign: .whenNegative, symbol: .custom(token.symbol))
            
            hideInputAccessoryView()
        }
        
        if let constant = amountTextField.attributedText?.size().width {
            symbolLeadingConstraint.constant = constant + 6
            amountSymbolLabel.isHidden = false
            amountSymbolLabel.superview?.layoutIfNeeded()
        }
        
        continueButton.isEnabled = amount > 0
    }
    
    @IBAction func continueAction(_ sender: Any) {
        guard
            !continueButton.isBusy,
            let token,
            let inputText = amountTextField.text?.trim(),
            let inputAmount = Decimal(string: inputText, locale: .current)
        else {
            return
        }
        
        continueButton.isBusy = true
        adjustBottomConstraintWhenKeyboardFrameChanges = false
        
        let tokenAmount: Decimal
        let fiatMoneyAmount: Decimal
        let fiatMoneyPrice = token.decimalUSDPrice * Decimal(Currency.current.rate)
        switch amountIntent {
        case .byToken:
            tokenAmount = inputAmount
            fiatMoneyAmount = tokenAmount * fiatMoneyPrice
        case .byFiatMoney:
            tokenAmount = inputAmount / fiatMoneyPrice
            fiatMoneyAmount = inputAmount
        }
        
        let memo = memoTextField.text?.trim() ?? ""
        let traceID = self.traceID
        let amountIntent = self.amountIntent
        
        let payment = Payment(traceID: traceID,
                              token: token,
                              tokenAmount: tokenAmount,
                              fiatMoneyAmount: fiatMoneyAmount,
                              memo: memo)
        let onPreconditonFailure = { (reason: PaymentPreconditionFailureReason) in
            self.continueButton.isBusy = false
            switch reason {
            case .userCancelled:
                self.adjustBottomConstraintWhenKeyboardFrameChanges = true
                self.amountTextField.becomeFirstResponder()
            case .description(let message):
                self.adjustBottomConstraintWhenKeyboardFrameChanges = true
                self.amountTextField.becomeFirstResponder()
                showAutoHiddenHud(style: .error, text: message)
            }
        }
        
        switch opponent {
        case .contact(let opponent):
            payment.checkPreconditions(
                transferTo: .user(opponent),
                reference: nil,
                on: self,
                onFailure: onPreconditonFailure
            ) { (operation, issues) in
                self.continueButton.isBusy = false
                let preview = TransferPreviewViewController(issues: issues,
                                                            operation: operation,
                                                            amountDisplay: amountIntent,
                                                            redirection: nil)
                self.present(preview, animated: true)
            }
        case .address(let address):
            guard let feeItem = selectedFeeItem else {
                return
            }
            payment.checkPreconditions(withdrawTo: .address(address), fee: feeItem, on: self, onFailure: onPreconditonFailure) { (operation, issues) in
                self.continueButton.isBusy = false
                let preview = WithdrawPreviewViewController(issues: issues,
                                                            operation: operation,
                                                            amountDisplay: amountIntent,
                                                            withdrawalTokenAmount: tokenAmount,
                                                            withdrawalFiatMoneyAmount: fiatMoneyAmount,
                                                            addressLabel: address.label)
                self.present(preview, animated: true)
            }
        case .mainnet(let address):
            payment.checkPreconditions(
                transferTo: .mainnet(address),
                reference: nil,
                on: self,
                onFailure: onPreconditonFailure
            ) { (operation, issues) in
                self.continueButton.isBusy = false
                let preview = TransferPreviewViewController(issues: issues,
                                                            operation: operation,
                                                            amountDisplay: amountIntent,
                                                            redirection: nil)
                self.present(preview, animated: true)
            }
        }
    }
    
    @IBAction func toggleAmountIntent(_ sender: Any) {
        guard let token else {
            return
        }
        switch amountIntent {
        case .byToken:
            amountIntent = .byFiatMoney
            amountSymbolLabel.text = Currency.current.code
        case .byFiatMoney:
            amountIntent = .byToken
            amountSymbolLabel.text = token.symbol
        }
        amountEditingChanged(sender)
    }
    
    @objc private func showTransactionHistory(_ sender: Any) {
        switch opponent {
        case let .contact(user):
            let history = TransactionHistoryViewController(user: user)
            navigationController?.pushViewController(history, animated: true)
        case let .address(address):
            // TODO: Reduce database access
            if let item = AddressDAO.shared.addressItem(id: address.addressId) {
                let history = TransactionHistoryViewController(address: item)
                navigationController?.pushViewController(history, animated: true)
            }
            break
        case .mainnet:
            break
        }
    }

    @objc private func switchToken(_ sender: Any) {
        guard !tokenSelectorView.accessoryImageView.isHidden else {
            return
        }
        let vc = TokenSelectorViewController()
        vc.delegate = self
        vc.tokens = availableTokens
        vc.token = token
        present(vc, animated: true, completion: nil)
    }
    
    @objc private func switchFeeToken(_ sender: Any) {
        guard let selectableFeeItems, let selectedFeeItemIndex else {
            return
        }
        let selector = WithdrawFeeSelectorViewController(fees: selectableFeeItems, selectedIndex: selectedFeeItemIndex) { index in
            self.selectedFeeItemIndex = index
            let feeToken = selectableFeeItems[index]
            self.updateNetworkFeeLabel(feeToken: feeToken)
        }
        present(selector, animated: true)
    }
    
    @objc private func fillBalanceAction(_ sender: Any) {
        guard let token else {
            return
        }
        amountTextField.text = token.localizedBalance
        amountEditingChanged(sender)
    }
    
    @objc private func fetchAvailableAssets() {
        tokenSelectorView.button.isUserInteractionEnabled = false
        DispatchQueue.global().async { [weak self] in
            let token: TokenItem
            if let id = self?.token?.assetID, let selected = TokenDAO.shared.tokenItem(assetID: id) {
                token = selected
            } else if let `default` = TokenDAO.shared.defaultTransferToken() {
                token = `default`
            } else {
                token = .xin
            }
            self?.token = token
            DispatchQueue.main.async {
                self?.updateViews(token: token)
            }
            
            let tokens = TokenDAO.shared.positiveBalancedTokens()
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.availableTokens = tokens
                if tokens.count > 1 {
                    self.tokenSelectorView.accessoryImageView.isHidden = false
                    self.tokenSelectorView.button.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        guard presentedViewController == nil else {
            return
        }
        amountTextField.becomeFirstResponder()
    }
    
    private func updateViews(token: TokenItem) {
        switchAmountIntentButton.isHidden = token.decimalBTCPrice <= 0
        tokenSelectorView.load(token: token)
        switch amountIntent {
        case .byToken:
            amountSymbolLabel.text = token.symbol
        case .byFiatMoney:
            amountSymbolLabel.text = Currency.current.code
        }
        switch opponent {
        case .mainnet:
            withdrawFeeView.networkLabel.text = token.depositNetworkName
            withdrawFeeView.minimumWithdrawalLabel.text = CurrencyFormatter.localizedString(from: minimumTransferAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        default:
            break
        }
    }
    
    private func reloadWithdrawFee(with token: TokenItem, address: Address) {
        continueButton.isBusy = true
        Task {
            do {
                let fees = try await SafeAPI.fees(assetID: token.assetID, destination: address.destination)
                guard let fee = fees.first else {
                    throw MixinAPIResponseError.withdrawSuspended
                }
                let allAssetIDs = fees.map(\.assetID)
                let missingAssetIDs = TokenDAO.shared.inexistAssetIDs(in: allAssetIDs)
                if !missingAssetIDs.isEmpty {
                    let tokens = try await SafeAPI.assets(ids: missingAssetIDs)
                    await withCheckedContinuation { continuation in
                        TokenDAO.shared.save(assets: tokens) {
                            continuation.resume()
                        }
                    }
                }
                let tokensMap = TokenDAO.shared.tokenItems(with: allAssetIDs)
                    .reduce(into: [:]) { result, item in
                        result[item.assetID] = item
                    }
                let feeTokens: [WithdrawFeeItem] = fees.compactMap { fee in
                    if let token = tokensMap[fee.assetID] {
                        return WithdrawFeeItem(amountString: fee.amount, tokenItem: token)
                    } else {
                        return nil
                    }
                }
                guard feeTokens.first?.tokenItem.assetID == fee.assetID else {
                    return
                }
                let feeToken = feeTokens[0]
                await MainActor.run {
                    self.selectedFeeItemIndex = 0
                    self.selectableFeeItems = feeTokens
                    self.withdrawFeeView.networkLabel.text = token.depositNetworkName
                    self.withdrawFeeView.minimumWithdrawalLabel.text = CurrencyFormatter.localizedString(from: address.decimalDust, format: .precision, sign: .never, symbol: .custom(token.symbol))
                    self.updateNetworkFeeLabel(feeToken: feeToken)
                    if feeTokens.count > 1 {
                        self.withdrawFeeView.switchFeeDisclosureIndicatorView.isHidden = false
                        self.withdrawFeeView.isUserInteractionEnabled = true
                    } else {
                        self.withdrawFeeView.switchFeeDisclosureIndicatorView.isHidden = true
                        self.withdrawFeeView.isUserInteractionEnabled = false
                    }
                    self.continueButton.isBusy = false
                }
            } catch MixinAPIResponseError.withdrawSuspended {
                await MainActor.run {
                    let suspended = WalletHintViewController(content: .withdrawSuspended(token))
                    suspended.delegate = self
                    present(suspended, animated: true)
                }
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    // Check token and address
                    self?.reloadWithdrawFee(with: token, address: address)
                }
            }
        }
    }
    
    private func showInputAccessoryView() {
        guard let token, amountTextField.inputAccessoryView == nil else {
            return
        }
        let balance = CurrencyFormatter.localizedString(from: token.balance, format: .precision, sign: .never)
            ?? token.localizedBalance
        balanceInputAccessoryView.balanceLabel.text = balance
        amountTextField.inputAccessoryView = balanceInputAccessoryView
        amountTextField.reloadInputViews()
    }
    
    private func hideInputAccessoryView() {
        guard amountTextField.inputAccessoryView != nil else {
            return
        }
        amountTextField.inputAccessoryView = nil
        amountTextField.reloadInputViews()
    }
    
    private func updateNetworkFeeLabel(feeToken: WithdrawFeeItem) {
        if feeToken.amount == 0 {
            withdrawFeeView.networkFeeLabel.text = "0"
        } else {
            withdrawFeeView.networkFeeLabel.text = CurrencyFormatter.localizedString(from: feeToken.amount, format: .precision, sign: .never, symbol: .custom(feeToken.tokenItem.symbol))
        }
    }
    
}

extension TransferOutViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        switch textField {
        case amountTextField:
            if newText.isEmpty {
                return true
            } else if newText.isNumeric {
                let components = newText.components(separatedBy: currentDecimalSeparator)
                switch amountIntent {
                case .byToken:
                    return components.count == 1 || components[1].count <= 8
                case .byFiatMoney:
                    return components.count == 1 || components[1].count <= 2
                }
            } else {
                return false
            }
        case memoTextField:
            return newText.utf8.count <= maxMemoDataCount
        default:
            return true
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case amountTextField:
            memoTextField.becomeFirstResponder()
        case memoTextField:
            continueAction(textField)
        default:
            break
        }
        return false
    }
    
}

extension TransferOutViewController: TokenSelectorViewControllerDelegate {
    
    func tokenSelectorViewController(_ viewController: TokenSelectorViewController, didSelectToken token: TokenItem) {
        self.token = token
        amountIntent = .byToken
        amountTextField.text = nil
        amountEditingChanged(viewController)
        updateViews(token: token)
    }
    
}

extension TransferOutViewController: WalletHintViewControllerDelegate {
    
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
        navigationController?.popViewController(animated: true)
    }
    
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
        guard let navigationController, let user = UserDAO.shared.getUser(identityNumber: "7000") else {
            return
        }
        let conversation = ConversationViewController.instance(ownerUser: user)
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.firstIndex(where: { $0 is HomeTabBarController }) {
            viewControllers.removeLast(viewControllers.count - index - 1)
        }
        viewControllers.append(conversation)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
}
