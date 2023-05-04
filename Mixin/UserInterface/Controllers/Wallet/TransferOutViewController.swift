import UIKit
import MixinServices

class TransferOutViewController: KeyboardBasedLayoutViewController {
    
    enum Opponent {
        case contact(UserItem)
        case address(Address)
        case tipWallet(String)
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
        let view = R.nib.balanceInputAccessoryView(owner: nil)!
        view.button.addTarget(self, action: #selector(fillBalanceAction(_:)), for: .touchUpInside)
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountExchangeLabel.text = "0" + currentDecimalSeparator + "00 " + Currency.current.code
        switch opponent! {
        case .contact(let user):
            targetUser = user
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
        case let .tipWallet(address):
            opponentImageView.image = R.image.wallet.ic_transaction_external_large()
            container?.titleLabel.text = "Bridge"
            container?.setSubtitle(subtitle: address.toSimpleKey())
            memoView.isHidden = true
            if let asset = asset {
                DispatchQueue.global().async { [weak self] in
                    let response = ExternalSchemeAPI.checkAddress(assetId: asset.assetId,
                                                                  destination: address,
                                                                  tag: nil)
                    guard case let .success(response) = response else {
                        return
                    }
                    guard let feeAsset = AssetDAO.shared.getAsset(assetId: response.feeAssetId) else {
                        return
                    }
                    let feeRepresentation = response.fee + " " + feeAsset.symbol
                    let feeHint = R.string.localizable.withdrawal_network_fee() + feeRepresentation
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        self.feeAsset = feeAsset
                        self.fee = response.fee
                        self.transactionFeeHintLabel.text = feeHint
                        self.continueButton.isBusy = false
                    }
                }
            }
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
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.payWindowIfLoaded == nil else {
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
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
        } else {
            let assetAmount = amountText.doubleValue / fiatMoneyPrice
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
        case .address(let address):
            DispatchQueue.global().async { [weak self] in
                guard let feeAsset = feeAsset ?? AssetDAO.shared.getAsset(assetId: address.feeAssetId) else {
                    return
                }

                let action: PayWindow.PinAction = .withdraw(trackId: traceId, address: address, feeAsset: feeAsset, fromWeb: false)
                PayWindow.checkPay(traceId: traceId, asset: asset, action: action, destination: address.destination, tag: address.tag, addressId: address.addressId, amount: amount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, fromWeb: false) { (canPay, errorMsg) in
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
        case let .tipWallet(address):
            continueButton.isBusy = false
            guard let fee, let feeAsset else {
                return
            }
            let addressId = (myUserId + asset.assetId + address).uuidDigest()
            let action: PayWindow.PinAction = .externalTransfer(destination: address, fee: fee, feeAsset: feeAsset, addressId: addressId, traceId: UUID().uuidString.lowercased())
            payWindow.render(asset: asset, action: action, amount: amount, isAmountLocalized: false, memo: memo).presentPopupControllerAnimated()
        }
    }
    
    @IBAction func switchAssetAction(_ sender: Any) {
        guard !assetSwitchImageView.isHidden else {
            return
        }
        let vc = TransferTypeViewController()
        vc.delegate = self
        vc.assets = availableAssets
        vc.asset = asset
        present(vc, animated: true, completion: nil)
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
        amountTextField.text = asset?.balance
        amountEditingChanged(sender)
    }
    
    @objc private func fetchAvailableAssets() {
        switchAssetButton.isUserInteractionEnabled = false
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
                    weakSelf.assetSwitchImageView.isHidden = false
                    weakSelf.switchAssetButton.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    @objc private func reloadAddress() {
        if case let .address(address) = opponent {
            DispatchQueue.global().async { [weak self] in
                guard let address = AddressDAO.shared.getAddress(addressId: address.addressId) else {
                    return
                }
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    self.opponent = .address(address)
                    self.fillFeeHint(address: address, onFinished: nil)
                }
            }
        }
    }
    
    private func updateAssetUI() {
        guard let asset = self.asset else {
            return
        }
        switchAmountButton.isHidden = asset.priceBtc.doubleValue <= 0
        nameLabel.text = asset.name
        let balance = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never)
            ?? asset.localizedBalance
        balanceLabel.text = balance + " " + asset.symbol
        assetIconView.setIcon(asset: asset)
        amountSymbolLabel.text = isInputAssetAmount ? asset.symbol : Currency.current.code
    }
    
    private func reloadTransactionFeeHint(addressId: String) {
        continueButton.isBusy = true
        DispatchQueue.global().async { [weak self] in
            if let address = AddressDAO.shared.getAddress(addressId: addressId), !address.feeAssetId.isEmpty {
                self?.fillFeeHint(address: address) {
                    self?.reloadFeeFromRemote(addressId: address.addressId)
                }
            } else {
                self?.reloadFeeFromRemote(addressId: addressId)
            }
        }
    }
    
    private func reloadFeeFromRemote(addressId: String) {
        WithdrawalAPI.address(addressId: addressId) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(address):
                DispatchQueue.global().async {
                    AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                }
                if case .address = weakSelf.opponent {
                    weakSelf.opponent = .address(address)
                }
                weakSelf.fillFeeHint(address: address, onFinished: nil)
            case .failure:
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: {
                    self?.reloadFeeFromRemote(addressId: addressId)
                })
            }
        }
    }
    
    private func fillFeeHint(address: Address, onFinished: (() -> Void)?) {
        let asset = self.asset
        DispatchQueue.global().async { [weak self] in
            guard let feeAsset = AssetDAO.shared.getAsset(assetId: address.feeAssetId) else {
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.transactionFeeHintLabel.text = ""
                    self.continueButton.isBusy = false
                }
                onFinished?()
                return
            }
            var hint: String
            var highlightRanges = [NSRange]()

            let feeRepresentation = address.fee + " " + feeAsset.symbol
            let feeHint = R.string.localizable.withdrawal_network_fee() + feeRepresentation
            hint = feeHint
            let range = (hint as NSString).range(of: feeRepresentation)
            highlightRanges.append(range)
            
            if let asset, address.dust.doubleValue > 0 {
                let dustRepresentation = address.dust + " " + asset.symbol
                let dustHint = R.string.localizable.withdrawal_minimum_withdrawal() + dustRepresentation
                hint += "\n" + dustHint
                let range = (hint as NSString).range(of: dustRepresentation, options: .backwards)
                highlightRanges.append(range)
            }
            
            if address.reserve.doubleValue > 0 {
                let reserveRepresentation = address.reserve + " " + feeAsset.symbol
                let reserveHint = R.string.localizable.withdrawal_minimum_reserve() + reserveRepresentation
                hint += "\n" + reserveHint
                let range = (hint as NSString).range(of: reserveRepresentation, options: .backwards)
                highlightRanges.append(range)
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            let attributedHint = NSMutableAttributedString(string: hint, attributes: [.paragraphStyle: paragraphStyle])
            highlightRanges.forEach { range in
                attributedHint.addAttribute(.foregroundColor, value: UIColor.text, range: range)
            }
            DispatchQueue.main.async {
                if let self {
                    self.feeAsset = feeAsset
                    self.transactionFeeHintLabel.attributedText = attributedHint
                    self.continueButton.isBusy = false
                }
                onFinished?()
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
        let vc = R.storyboard.wallet.send()!
        vc.opponent = type
        vc.asset = asset
        let container = ContainerViewController.instance(viewController: vc, title: "")
        return container
    }
    
}

extension TransferOutViewController: ContainerViewControllerDelegate {

    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }

    func barRightButtonTappedAction() {
        switch opponent! {
        case let .contact(user):
            let vc = PeerTransactionsViewController.instance(opponentId: user.userId)
            navigationController?.pushViewController(vc, animated: true)
        case let .address(address):
            let vc = AddressTransactionsViewController.instance(asset: address.assetId, destination: address.destination, tag: address.tag)
            navigationController?.pushViewController(vc, animated: true)
        case .tipWallet:
            break
        }
    }

    func imageBarRightButton() -> UIImage? {
        switch opponent {
        case .tipWallet:
            return nil
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

extension TransferOutViewController: TransferTypeViewControllerDelegate {
    
    func transferTypeViewController(_ viewController: TransferTypeViewController, didSelectAsset asset: AssetItem) {
        self.asset = asset
        isInputAssetAmount = true
        if let amountTextField = amountTextField {
            amountTextField.text = nil
            amountEditingChanged(amountTextField)
        }
        updateAssetUI()
    }
    
}
