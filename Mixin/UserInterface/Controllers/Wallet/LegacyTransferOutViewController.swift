import UIKit
import MixinServices

class LegacyTransferOutViewController: KeyboardBasedLayoutViewController {
    
    enum Opponent {
        case contact(UserItem)
    }
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var opponentImageView: AvatarImageView!
    @IBOutlet weak var assetSelectorView: AssetComboBoxView!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var amountSymbolLabel: UILabel!
    @IBOutlet weak var transcationFeeHintView: UIView!
    @IBOutlet weak var transactionFeeHintLabel: UILabel!
    @IBOutlet weak var continueWrapperView: UIView!
    @IBOutlet weak var switchAmountButton: UIButton!
    @IBOutlet weak var memoView: CornerView!

    @IBOutlet weak var continueWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var symbolLeadingConstraint: NSLayoutConstraint!
    
    private let placeHolderFont = UIFont.preferredFont(forTextStyle: .callout)
    private let amountFont = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
    private let maxMemoDataCount = 200
    
    private var availableAssets = [AssetItem]()
    private var opponent: Opponent!
    private var asset: AssetItem?
    private var targetUser: UserItem?
    private var feeAsset: AssetItem?
    private var isInputAssetAmount = true
    private var adjustBottomConstraintWhenKeyboardFrameChanges = true
    
    // Remove after TIP Wallet transfer is removed
    private var fee: String?
    
    private weak var payWindowIfLoaded: PayWindow?
    
    private lazy var traceId = UUID().uuidString.lowercased()
    private lazy var balanceInputAccessoryView: BalanceInputAccessoryView = {
        let view = R.nib.balanceInputAccessoryView(withOwner: nil)!
        view.button.addTarget(self, action: #selector(fillBalanceAction(_:)), for: .touchUpInside)
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        assetSelectorView.button.addTarget(self, action: #selector(switchAssetAction(_:)), for: .touchUpInside)
        amountExchangeLabel.text = "0" + currentDecimalSeparator + "00 " + Currency.current.code
        switch opponent! {
        case .contact(let user):
            targetUser = user
            opponentImageView.setImage(with: user)
            container?.setSubtitle(subtitle: user.isCreatedByMessenger ? user.identityNumber : user.userId)
            container?.titleLabel.text = R.string.localizable.send_to_title() + " " + user.fullName
        }
        
        if self.asset != nil {
            updateAssetUI()
        } else {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(fetchAvailableAssets),
                                                   name: AssetDAO.assetsDidChangeNotification,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(fetchAvailableAssets),
                                                   name: ChainDAO.chainsDidChangeNotification,
                                                   object: nil)
            ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
            fetchAvailableAssets()
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
        scrollView.contentInset.bottom = keyboardHeight + continueWrapperView.frame.height
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        view.layoutIfNeeded()
        if !viewHasAppeared, ScreenHeight.current <= .short {
            scrollView.contentOffset.y = opponentImageView.frame.maxY
        }
    }
    
    @IBAction func amountEditingChanged(_ sender: Any) {
        guard let asset = self.asset else {
            return
        }
        let amountText = amountTextField.text ?? ""
        amountTextField.font = amountText.isEmpty ? placeHolderFont : amountFont
        guard amountText.isNumeric else {
            if isInputAssetAmount {
                amountExchangeLabel.text = "0" + currentDecimalSeparator + "00 " + Currency.current.code
            } else {
                amountExchangeLabel.text = "0 " + asset.symbol
            }
            amountSymbolLabel.isHidden = true
            continueButton.isEnabled = false
            return
        }
        
        let fiatMoneyPrice = asset.priceUsd.doubleValue * Currency.current.rate
        if isInputAssetAmount {
            let fiatMoneyAmount = amountText.doubleValue * fiatMoneyPrice
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencyCode)
        } else {
            let assetAmount = amountText.doubleValue / fiatMoneyPrice
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: assetAmount, format: .pretty, sign: .whenNegative, symbol: .custom(asset.symbol))
        }
        
        if isInputAssetAmount {
            if amountTextField.text == asset.balance {
                hideInputAccessoryView()
            } else if amountText.count >= 4, asset.balance.doubleValue != 0, asset.localizedBalance.hasPrefix(amountText) {
                showInputAccessoryView()
            } else {
                hideInputAccessoryView()
            }
        } else {
            hideInputAccessoryView()
        }
        
        if let constant = amountTextField.attributedText?.size().width {
            symbolLeadingConstraint.constant = constant + 6
            amountSymbolLabel.isHidden = false
            amountSymbolLabel.superview?.layoutIfNeeded()
        }
        
        continueButton.isEnabled = amountText.doubleValue > 0
    }
    
    @IBAction func continueAction(_ sender: Any) {
        guard let asset = self.asset else {
            return
        }
        guard !continueButton.isBusy else {
            return
        }
        continueButton.isBusy = true
        
        let memo = memoTextField.text?.trim() ?? ""
        var amount = amountTextField.text?.trim() ?? ""
        var fiatMoneyAmount: String? = nil
        if !isInputAssetAmount {
            fiatMoneyAmount = amount
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            formatter.usesGroupingSeparator = false
            formatter.maximumFractionDigits = 8
            formatter.roundingMode = .down
            let fiatMoneyPrice = asset.priceUsd.doubleValue * Currency.current.rate
            let number = NSNumber(value: amount.doubleValue / fiatMoneyPrice)
            amount = formatter.string(from: number) ?? ""
        }
        
        adjustBottomConstraintWhenKeyboardFrameChanges = false

        let feeAsset = self.feeAsset
        let traceId = self.traceId
        let payWindow = PayWindow.instance()
        payWindow.onDismiss = { [weak self] in
            self?.adjustBottomConstraintWhenKeyboardFrameChanges = true
        }
        self.payWindowIfLoaded = payWindow
        
        switch opponent! {
        case .contact(let user):
            DispatchQueue.global().async { [weak self] in
                let action: PayWindow.PinAction = .transfer(trackId: traceId, user: user, fromWeb: false, returnTo: nil)
                PayWindow.checkPay(traceId: traceId, asset: asset, action: action, opponentId: user.userId, amount: amount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, fromWeb: false) { (canPay, errorMsg) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        weakSelf.continueButton.isBusy = false
                        if canPay {
                            payWindow.render(asset: asset, action: action, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount, textfield: weakSelf.amountTextField).presentPopupControllerAnimated()
                        } else {
                            weakSelf.amountTextField.becomeFirstResponder()
                            if let error = errorMsg {
                                showAutoHiddenHud(style: .error, text: error)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func switchAmountAction(_ sender: Any) {
        guard let asset = self.asset else {
            return
        }
        isInputAssetAmount = !isInputAssetAmount
        amountSymbolLabel.text = isInputAssetAmount ? asset.symbol : Currency.current.code
        if let amountTextField = amountTextField {
            amountEditingChanged(amountTextField)
        }
    }
    
    @objc func fillBalanceAction(_ sender: Any) {
        guard let asset else {
            return
        }
        amountTextField.text = asset.localizedBalance
        amountEditingChanged(sender)
    }
    
    @objc private func switchAssetAction(_ sender: Any) {
        guard !assetSelectorView.accessoryImageView.isHidden else {
            return
        }
        let vc = LegacyTransferTypeViewController()
        vc.delegate = self
        vc.assets = availableAssets
        vc.asset = asset
        present(vc, animated: true, completion: nil)
    }
    
    @objc private func fetchAvailableAssets() {
        assetSelectorView.button.isUserInteractionEnabled = false
        DispatchQueue.global().async { [weak self] in
            if let assetId = self?.asset?.assetId, let asset = AssetDAO.shared.getAsset(assetId: assetId) {
                self?.asset = asset
                DispatchQueue.main.async {
                    self?.updateAssetUI()
                }
            } else {
                if let defaultAsset = AssetDAO.shared.getDefaultTransferAsset() {
                    self?.asset = defaultAsset
                } else {
                    self?.asset = .xin
                }
                DispatchQueue.main.async {
                    self?.updateAssetUI()
                }
            }
            
            let assets = AssetDAO.shared.getAvailableAssets()
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.availableAssets = assets
                if assets.count > 1 {
                    weakSelf.assetSelectorView.accessoryImageView.isHidden = false
                    weakSelf.assetSelectorView.button.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        guard payWindowIfLoaded == nil else {
            return
        }
        amountTextField.becomeFirstResponder()
    }
    
    private func updateAssetUI() {
        guard let asset = self.asset else {
            return
        }
        switchAmountButton.isHidden = asset.priceBtc.doubleValue <= 0
        assetSelectorView.load(asset: asset)
        amountSymbolLabel.text = isInputAssetAmount ? asset.symbol : Currency.current.code
    }
    
    private func showInputAccessoryView() {
        guard amountTextField.inputAccessoryView == nil else {
            return
        }
        guard let asset = asset else {
            return
        }
        let balance = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never)
            ?? asset.localizedBalance
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
    
    class func instance(asset: AssetItem?, type: Opponent) -> UIViewController {
        let vc = R.storyboard.wallet.send()!
        vc.opponent = type
        vc.asset = asset
        let container = ContainerViewController.instance(viewController: vc, title: "")
        return container
    }
    
}

extension LegacyTransferOutViewController: ContainerViewControllerDelegate {

    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }

    func barRightButtonTappedAction() {
        switch opponent! {
        case let .contact(user):
            let history = TransactionHistoryViewController(user: user)
            navigationController?.pushViewController(history, animated: true)
        }
    }

    func imageBarRightButton() -> UIImage? {
        switch opponent {
        default:
            return R.image.ic_title_transaction()
        }
    }

}

extension LegacyTransferOutViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        switch textField {
        case amountTextField:
            if newText.isEmpty {
                return true
            } else if newText.isNumeric {
                let components = newText.components(separatedBy: currentDecimalSeparator)
                if isInputAssetAmount {
                    return components.count == 1 || components[1].count <= 8
                } else {
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

extension LegacyTransferOutViewController: LegacyTransferTypeViewControllerDelegate {
    
    func transferTypeViewController(_ viewController: LegacyTransferTypeViewController, didSelectAsset asset: AssetItem) {
        self.asset = asset
        isInputAssetAmount = true
        if let amountTextField = amountTextField {
            amountTextField.text = nil
            amountEditingChanged(amountTextField)
        }
        updateAssetUI()
    }
    
}
