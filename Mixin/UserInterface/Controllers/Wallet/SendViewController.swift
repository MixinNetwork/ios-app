import UIKit

class SendViewController: KeyboardBasedLayoutViewController {
    
    enum Opponent {
        case contact(UserItem)
        case address(Address)
    }
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var opponentImageView: AvatarImageView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var switchAssetButton: UIButton!
    @IBOutlet weak var assetSwitchImageView: UIImageView!
    @IBOutlet weak var amountSymbolLabel: UILabel!
    @IBOutlet weak var transactionFeeHintLabel: UILabel!
    @IBOutlet weak var continueWrapperView: UIView!
    @IBOutlet weak var switchAmountButton: UIButton!
    @IBOutlet weak var memoView: CornerView!

    @IBOutlet weak var opponentImageViewWidthConstraint: ScreenSizeCompatibleLayoutConstraint!
    @IBOutlet weak var continueWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var symbolLeadingConstraint: NSLayoutConstraint!
    
    private let placeHolderFont = UIFont.systemFont(ofSize: 16)
    private let amountFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    
    private var availableAssets = [AssetItem]()
    private var opponent: Opponent!
    private var asset: AssetItem?
    private var targetUser: UserItem?
    private var targetAddress: Address?
    private var isInputAssetAmount = true
    private var adjustBottomConstraintWhenKeyboardFrameChanges = true
    
    private lazy var tranceId = UUID().uuidString.lowercased()
    private lazy var balanceInputAccessoryView: BalanceInputAccessoryView = {
        let view = R.nib.balanceInputAccessoryView(owner: nil)!
        view.button.addTarget(self, action: #selector(fillBalanceAction(_:)), for: .touchUpInside)
        return view
    }()
    private lazy var transactionLabelAttribute: [NSAttributedString.Key: Any] = {
        return [.font: transactionFeeHintLabel.font,
                .foregroundColor: transactionFeeHintLabel.textColor]
    }()
    private lazy var transactionLabelBoldAttribute: [NSAttributedString.Key: Any] = {
        let normalFont = transactionFeeHintLabel.font!
        let boldFont: UIFont
        if let descriptor = normalFont.fontDescriptor.withSymbolicTraits(.traitBold) {
            boldFont = UIFont(descriptor: descriptor, size: normalFont.pointSize)
        } else {
            boldFont = UIFont.boldSystemFont(ofSize: normalFont.pointSize)
        }
        return [.font: boldFont,
                .foregroundColor: transactionFeeHintLabel.textColor]
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        opponentImageView.cornerRadius = opponentImageViewWidthConstraint.constant / 2
        switch opponent! {
        case .contact(let user):
            targetUser = user
            opponentImageView.setImage(with: user)
            container?.setSubtitle(subtitle: user.identityNumber)
            container?.titleLabel.text = Localized.ACTION_SEND_TO + " " + user.fullName
        case .address(let address):
            targetAddress = address
            opponentImageView.image = R.image.wallet.ic_transaction_external_large()
            reloadTransactionFeeHint(addressId: address.addressId)
        }
        
        if self.asset != nil {
            updateAssetUI()
        } else {
            fetchAvailableAssets()
        }
        
        amountTextField.becomeFirstResponder()
        amountTextField.delegate = self
    }
    
    override func keyboardWillChangeFrame(_ notification: Notification) {
        guard adjustBottomConstraintWhenKeyboardFrameChanges else {
            return
        }
        super.keyboardWillChangeFrame(notification)
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let windowHeight = AppDelegate.current.window!.bounds.height
        let keyboardHeight = windowHeight - keyboardFrame.origin.y
        continueWrapperBottomConstraint.constant = keyboardHeight
        scrollView.contentInset.bottom = keyboardHeight + continueWrapperView.frame.height
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight
        view.layoutIfNeeded()
        if !viewHasAppeared, ScreenSize.current <= .inch4 {
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
            amountExchangeLabel.text = isInputAssetAmount ? "0\(currentDecimalSeparator)00 USD" : "0 " + asset.symbol
            amountSymbolLabel.isHidden = true
            continueButton.isEnabled = false
            return
        }
        
        if isInputAssetAmount {
            let usdAmount = amountText.doubleValue * asset.priceUsd.doubleValue
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: usdAmount, format: .legalTender, sign: .never, symbol: .usd)
        } else {
            let assetAmount = amountText.doubleValue / asset.priceUsd.doubleValue
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: assetAmount, format: .pretty, sign: .whenNegative, symbol: .custom(asset.symbol))
        }
        
        if isInputAssetAmount {
            if amountTextField.text == asset.balance {
                hideInputAccessoryView()
            } else if amountText.count >= 4, asset.balance.doubleValue != 0, asset.balance.hasPrefix(amountText) {
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
        
        let memo = memoTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var amount = amountTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var amountUsd: String? = nil
        if !isInputAssetAmount {
            amountUsd = amount + " USD"
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            formatter.usesGroupingSeparator = false
            formatter.maximumFractionDigits = 8
            formatter.roundingMode = .down
            amount = formatter.string(from: NSNumber(value: amount.doubleValue / asset.priceUsd.doubleValue)) ?? ""
        }
        
        adjustBottomConstraintWhenKeyboardFrameChanges = false
        let payWindow = Bundle.main.loadNibNamed("PayWindow", owner: nil, options: nil)?.first as! PayWindow
        payWindow.onDismiss = { [weak self] in
            self?.adjustBottomConstraintWhenKeyboardFrameChanges = true
        }
        switch opponent! {
        case .contact(let user):
            payWindow.presentPopupControllerAnimated(asset: asset, user: user, amount: amount, memo: memo, trackId: tranceId, amountUsd: amountUsd, textfield: amountTextField)
        case .address(let address):
            guard checkAmount(amount, isGreaterThanOrEqualToDust: address.dust) else {
                showHud(style: .error, text: Localized.WITHDRAWAL_MINIMUM_AMOUNT(amount: address.dust, symbol: asset.symbol))
                return
            }
            payWindow.presentPopupControllerAnimated(asset: asset, address: address, amount: amount, memo: memo, trackId: tranceId, amountUsd: amountUsd, textfield: amountTextField)
        }
    }
    
    @IBAction func switchAssetAction(_ sender: Any) {
        guard !assetSwitchImageView.isHidden else {
            return
        }
        let vc = R.storyboard.chat.transferType()!
        vc.delegate = self
        vc.assets = availableAssets
        vc.asset = asset
        vc.transitioningDelegate = PopupPresentationManager.shared
        vc.modalPresentationStyle = .custom
        present(vc, animated: true, completion: nil)
    }
    
    @IBAction func switchAmountAction(_ sender: Any) {
        guard let asset = self.asset else {
            return
        }
        isInputAssetAmount = !isInputAssetAmount
        amountSymbolLabel.text = isInputAssetAmount ? asset.symbol : "USD"
        amountEditingChanged(amountTextField)
    }
    
    @objc func fillBalanceAction(_ sender: Any) {
        amountTextField.text = asset?.balance
        amountEditingChanged(sender)
    }
    
    private func fetchAvailableAssets() {
        switchAssetButton.isUserInteractionEnabled = false
        DispatchQueue.global().async { [weak self] in
            if self?.asset == nil {
                if let defaultAsset = AssetDAO.shared.getDefaultTransferAsset() {
                    self?.asset = defaultAsset
                } else {
                    self?.asset = AssetItem.createDefaultAsset()
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
                    weakSelf.assetSwitchImageView.isHidden = false
                    weakSelf.switchAssetButton.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    private func updateAssetUI() {
        guard let asset = self.asset else {
            return
        }
        if case .address = opponent! {
            if asset.assetId == "23dfb5a5-5d7b-48b6-905f-3970e3176e27" {
                memoTextField.placeholder = R.string.localizable.wallet_send_tag()
            } else {
                memoTextField.placeholder = R.string.localizable.wallet_send_memo()
            }
        }
        
        switchAmountButton.isHidden = asset.priceBtc.doubleValue <= 0
        nameLabel.text = asset.name
        let balance = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never)
            ?? asset.localizedBalance
        balanceLabel.text = balance + " " + asset.symbol
        assetIconView.setIcon(asset: asset)
        
        if let address = self.targetAddress {
            if asset.isAccount {
                container?.titleLabel.text = Localized.ACTION_SEND_TO + " " + (address.accountName ?? "")
                container?.setSubtitle(subtitle: address.accountTag?.toSimpleKey())
                memoView.isHidden = true
            } else {
                container?.titleLabel.text = Localized.ACTION_SEND_TO + " " + (address.label ?? "")
                container?.setSubtitle(subtitle: address.publicKey?.toSimpleKey())
                memoView.isHidden = false
            }
        }
        amountSymbolLabel.text = isInputAssetAmount ? asset.symbol : "USD"
    }
    
    private func checkAmount(_ amount: String, isGreaterThanOrEqualToDust dust: String) -> Bool {
        guard let amount = Decimal(string: amount, locale: .current), let dust = Decimal(string: dust, locale: .us) else {
            return false
        }
        return amount >= dust
    }
    
    private func reloadTransactionFeeHint(addressId: String) {
        displayFeeHint(loading: true)
        WithdrawalAPI.shared.address(addressId: addressId) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(address):
                weakSelf.fillFeeHint(address: address)
            case .failure:
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: {
                    self?.reloadTransactionFeeHint(addressId: addressId)
                })
            }
        }
    }
    
    private func displayFeeHint(loading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.transactionFeeHintLabel.isHidden = loading
        }
    }
    
    private func fillFeeHint(address: Address) {
        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: address.assetId), let chainAsset = AssetDAO.shared.getAsset(assetId: asset.chainId) else {
                self?.transactionFeeHintLabel.text = ""
                self?.displayFeeHint(loading: false)
                return
            }
            
            let feeRepresentation = address.fee + " " + chainAsset.symbol
            var hint = Localized.WALLET_HINT_TRANSACTION_FEE(feeRepresentation: feeRepresentation, name: asset.name)
            var ranges = [(hint as NSString).range(of: feeRepresentation)]
            if address.reserve.doubleValue > 0 {
                let reserveRepresentation = address.reserve + " " + chainAsset.symbol
                let reserveHint = Localized.WALLET_WITHDRAWAL_RESERVE(reserveRepresentation: reserveRepresentation, name: chainAsset.name)
                let reserveRange = (reserveHint as NSString).range(of: reserveRepresentation)
                ranges.append(NSRange(location: hint.count + reserveRange.location, length: reserveRange.length))
                hint += reserveHint
            }
            
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                let attributedHint = NSMutableAttributedString(string: hint, attributes: weakSelf.transactionLabelAttribute)
                for range in ranges {
                    attributedHint.addAttributes(weakSelf.transactionLabelBoldAttribute, range: range)
                }
                weakSelf.transactionFeeHintLabel.attributedText = attributedHint
                weakSelf.displayFeeHint(loading: false)
            }
        }
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
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "send") as! SendViewController
        vc.opponent = type
        vc.asset = asset
        let container = ContainerViewController.instance(viewController: vc, title: "")
        return container
    }
    
}

extension SendViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == amountTextField else {
            return true
        }
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
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
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == amountTextField {
            memoTextField.becomeFirstResponder()
        } else if textField == memoTextField {
            continueAction(textField)
        }
        return false
    }
    
}

extension SendViewController: TransferTypeViewControllerDelegate {
    
    func transferTypeViewController(_ viewController: TransferTypeViewController, didSelectAsset asset: AssetItem) {
        self.asset = asset
        isInputAssetAmount = true
        amountTextField.text = nil
        amountEditingChanged(amountTextField)

        updateAssetUI()
    }
    
}
