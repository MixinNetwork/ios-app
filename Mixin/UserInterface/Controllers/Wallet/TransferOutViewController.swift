import UIKit
import MixinServices

class TransferOutViewController: KeyboardBasedLayoutViewController {
    
    enum Opponent {
        case contact(UserItem)
        case address(Address)
    }
    
    @IBOutlet weak var contentScrollView: UIScrollView!
    @IBOutlet weak var opponentImageView: AvatarImageView!
    @IBOutlet weak var assetSelectorView: AssetComboBoxView!
    
    @IBOutlet weak var amountSymbolLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var switchAmountIntentButton: UIButton!
    
    @IBOutlet weak var memoView: CornerView!
    @IBOutlet weak var memoTextField: UITextField!
    
    @IBOutlet weak var transcationFeeHintView: UIView!
    @IBOutlet weak var transactionFeeHintLabel: UILabel!
    
    @IBOutlet weak var continueWrapperView: UIView!
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountExchangeLabel.text = "0" + currentDecimalSeparator + "00 " + Currency.current.code
        switch opponent {
        case .contact(let user):
            opponentImageView.setImage(with: user)
            container?.setSubtitle(subtitle: user.isCreatedByMessenger ? user.identityNumber : user.userId)
            container?.titleLabel.text = R.string.localizable.send_to_title() + " " + user.fullName
        case .address(let address):
            opponentImageView.image = R.image.wallet.ic_transaction_external_large()
            container?.titleLabel.text = R.string.localizable.send_to_title() + " " + address.label
            container?.setSubtitle(subtitle: address.fullAddress.toSimpleKey())
            memoView.isHidden = true
            reloadTransactionFeeHint(addressId: address.addressId)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(reloadAddress),
                                                   name: AddressDAO.addressDidChangeNotification,
                                                   object: nil)
        }
        
        if let token {
            updateViews(token: token)
        } else {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(fetchAvailableAssets),
                                                   name: TokenDAO.tokensDidChangeNotification,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(fetchAvailableAssets),
                                                   name: ChainDAO.chainsDidChangeNotification,
                                                   object: nil)
            ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
            fetchAvailableAssets()
        }
        
        amountTextField.adjustsFontForContentSizeCategory = true
        amountTextField.becomeFirstResponder()
        amountTextField.delegate = self
        memoTextField.delegate = self
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.presentedViewController == nil else {
                return
            }
            self.amountTextField.becomeFirstResponder()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
            
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
        let validator = PaymentValidator(traceID: traceID, token: token, memo: memo)
        
        adjustBottomConstraintWhenKeyboardFrameChanges = false
        
        switch opponent {
        case let .contact(opponent):
            validator.transfer(to: opponent, amount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount) { [weak self] result in
                guard let self else {
                    return
                }
                self.continueButton.isBusy = false
                switch result {
                case .passed:
                    let transfer = PeerTransferViewController(opponent: opponent,
                                                              token: token,
                                                              amountDisplay: amountIntent,
                                                              tokenAmount: tokenAmount,
                                                              fiatMoneyAmount: fiatMoneyAmount,
                                                              memo: memo,
                                                              traceID: traceID)
                    let authentication = AuthenticationViewController(intentViewController: transfer)
                    self.present(authentication, animated: true)
                case .userCancelled:
                    self.adjustBottomConstraintWhenKeyboardFrameChanges = true
                case .failure(let message):
                    self.adjustBottomConstraintWhenKeyboardFrameChanges = true
                    self.amountTextField.becomeFirstResponder()
                    showAutoHiddenHud(style: .error, text: message)
                }
            }
        case let .address(address):
            break
        }
    }
    
    @IBAction func switchAmountAction(_ sender: Any) {
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
    
    @IBAction func switchAssetAction(_ sender: Any) {
        guard !assetSelectorView.accessoryImageView.isHidden else {
            return
        }
        let vc = TokenSelectorViewController()
        vc.delegate = self
        vc.tokens = availableTokens
        vc.token = token
        present(vc, animated: true, completion: nil)
    }
    
    @objc func fillBalanceAction(_ sender: Any) {
        guard let token else {
            return
        }
        amountTextField.text = token.localizedBalance
        amountEditingChanged(sender)
    }
    
    @objc private func fetchAvailableAssets() {
        assetSelectorView.button.isUserInteractionEnabled = false
        DispatchQueue.global().async { [weak self] in
            let token: TokenItem
            if let id = self?.token?.assetID, let selected = TokenDAO.shared.tokenItem(with: id) {
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
                    self.assetSelectorView.accessoryImageView.isHidden = false
                    self.assetSelectorView.button.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    @objc private func reloadAddress() {
//        if case let .address(address) = opponent {
//            DispatchQueue.global().async { [weak self] in
//                guard let address = AddressDAO.shared.getAddress(addressId: address.addressId) else {
//                    return
//                }
//                DispatchQueue.main.async {
//                    guard let self = self else {
//                        return
//                    }
//                    self.opponent = .address(address)
//                    self.fillFeeHint(address: address, onFinished: nil)
//                }
//            }
//        }
    }
    
    private func updateViews(token: TokenItem) {
        switchAmountIntentButton.isHidden = token.decimalBTCPrice <= 0
        assetSelectorView.load(token: token)
        switch amountIntent {
        case .byToken:
            amountSymbolLabel.text = token.symbol
        case .byFiatMoney:
            amountSymbolLabel.text = Currency.current.code
        }
    }
    
    private func reloadTransactionFeeHint(addressId: String) {
//        continueButton.isBusy = true
//        DispatchQueue.global().async { [weak self] in
//            if let address = AddressDAO.shared.getAddress(addressId: addressId), !address.feeAssetId.isEmpty {
//                self?.fillFeeHint(address: address) {
//                    self?.reloadFeeFromRemote(addressId: address.addressId)
//                }
//            } else {
//                self?.reloadFeeFromRemote(addressId: addressId)
//            }
//        }
    }
    
    private func reloadFeeFromRemote(addressId: String) {
//        WithdrawalAPI.address(addressId: addressId) { [weak self](result) in
//            guard let weakSelf = self else {
//                return
//            }
//            switch result {
//            case let .success(address):
//                DispatchQueue.global().async {
//                    AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
//                }
//                if case .address = weakSelf.opponent {
//                    weakSelf.opponent = .address(address)
//                }
//                weakSelf.fillFeeHint(address: address, onFinished: nil)
//            case .failure:
//                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: {
//                    self?.reloadFeeFromRemote(addressId: addressId)
//                })
//            }
//        }
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
    
    class func instance(token: TokenItem?, to opponent: Opponent) -> UIViewController {
        let controller = TransferOutViewController(token: token, to: opponent)
        let container = ContainerViewController.instance(viewController: controller, title: "")
        return container
    }
    
}

extension TransferOutViewController: ContainerViewControllerDelegate {

    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }

    func barRightButtonTappedAction() {
        switch opponent {
        case let .contact(user):
            let vc = PeerTransactionsViewController.instance(opponentId: user.userId)
            navigationController?.pushViewController(vc, animated: true)
        case let .address(address):
            let vc = AddressTransactionsViewController.instance(asset: address.assetId, destination: address.destination, tag: address.tag)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func imageBarRightButton() -> UIImage? {
        switch opponent {
        default:
            return R.image.ic_title_transaction()
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
