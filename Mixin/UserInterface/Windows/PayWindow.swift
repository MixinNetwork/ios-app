import UIKit
import Foundation
import LocalAuthentication
import AudioToolbox

class PayWindow: BottomSheetView {

    enum PinAction {
        case payment(payment: PaymentCodeResponse, receivers: [UserResponse])
        case transfer(trackId: String, user: UserItem, fromWeb: Bool)
        case withdraw(trackId: String, address: Address, fromWeb: Bool)
        case multisig(multisig: MultisigResponse, senders: [UserResponse], receivers: [UserResponse])
    }

    enum ErrorContinueAction {
        case retryPin
        case changeAmount
        case close
    }

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var memoPlaceView: UIView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var successView: UIView!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var paySuccessImageView: UIImageView!
    @IBOutlet weak var payLabel: UILabel!
    @IBOutlet weak var biometricButton: UIButton!
    @IBOutlet weak var multisigView: UIView!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var pinView: UIView!
    @IBOutlet weak var errorContinueButton: RoundedButton!

    @IBOutlet weak var senderViewOne: AvatarImageView!
    @IBOutlet weak var senderViewTwo: AvatarImageView!
    @IBOutlet weak var senderMoreView: CornerView!
    @IBOutlet weak var senderMoreLabel: UILabel!
    @IBOutlet weak var receiverViewOne: AvatarImageView!
    @IBOutlet weak var receiverViewTwo: AvatarImageView!
    @IBOutlet weak var receiverMoreView: CornerView!
    @IBOutlet weak var receiverMoreLabel: UILabel!
    @IBOutlet weak var multisigActionView: UIImageView!
    @IBOutlet weak var multisigStackView: UIStackView!
    @IBOutlet weak var bigAmountTipsView: UIView!
    @IBOutlet weak var bigAmountConfirmButton: RoundedButton!
    @IBOutlet weak var bigAmountCancelButton: UIButton!
    @IBOutlet weak var bigAmountTitleSpaceView: UIView!
    @IBOutlet weak var bigAmountIconSpaceView: UIView!

    @IBOutlet weak var sendersButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var receiversButtonWidthConstraint: NSLayoutConstraint!

    private lazy var context = LAContext()
    private weak var textfield: UITextField?

    private var pinAction: PinAction!
    private var errorContinueAction: ErrorContinueAction?
    private var asset: AssetItem!
    private var amount = ""
    private var memo = ""
    private var soundId: SystemSoundID = 0
    private var isAutoFillPIN = false
    private var processing = false
    private var isKeyboardAppear = false
    private var isMultisigUsersAppear = false
    private var isAllowBiometricPay: Bool {
        guard AppGroupUserDefaults.Wallet.payWithBiometricAuthentication else {
            return false
        }
        guard let date = AppGroupUserDefaults.Wallet.lastPinVerifiedDate, -date.timeIntervalSinceNow < AppGroupUserDefaults.Wallet.biometricPaymentExpirationInterval else {
            return false
        }
        guard biometryType != .none else {
            return false
        }
        return true
    }
    private weak var bigAmountTimer: Timer?
    private var countdown = 3

    var onDismiss: (() -> Void)?

    deinit {
        bigAmountTimer?.invalidate()
        bigAmountTimer = nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if ScreenSize.current == .inch3_5 {
            pinField.cellLength = 8
        }
        pinField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func render(asset: AssetItem, action: PinAction, amount: String, memo: String, error: String? = nil, fiatMoneyAmount: String? = nil, textfield: UITextField? = nil) -> PayWindow {
        self.asset = asset
        self.amount = amount
        self.memo = memo
        self.pinAction = action
        self.textfield = textfield

        let amountToken = CurrencyFormatter.localizedString(from: amount, locale: .current, format: .precision, sign: .whenNegative, symbol: .custom(asset.symbol))
        if let fiatMoneyAmount = fiatMoneyAmount {
            amountLabel.text = fiatMoneyAmount
            amountExchangeLabel.text = amountToken
        } else {
            amountLabel.text = amountToken
            let value = amount.doubleValue * asset.priceUsd.doubleValue * Currency.current.rate
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: value, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
        }

        let showError = !(error?.isEmpty ?? true)
        let showBiometric = isAllowBiometricPay
        var showBigAmountTips = false
        switch pinAction! {
        case let .transfer(_, user, _):
            multisigView.isHidden = true
            let fiatMoneyValue = amount.doubleValue * asset.priceUsd.doubleValue * Currency.current.rate
            let threshold = Account.current?.transfer_confirmation_threshold ?? 0
            if fiatMoneyValue < threshold {
                showTransferView(user: user, showError: showError, showBiometric: showBiometric)
            } else {
                showBigAmountTips = true
                nameLabel.text = R.string.localizable.transfer_large_title()
                mixinIDLabel.text = R.string.localizable.transfer_large_prompt(amountExchangeLabel.text ?? "", asset.symbol, user.fullName)
                mixinIDLabel.textColor = .walletRed
                pinView.isHidden = true
                bigAmountTipsView.isHidden = false
                bigAmountTitleSpaceView.isHidden = false
                bigAmountIconSpaceView.isHidden = false
                updateContinueButton()
                bigAmountTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (timer) in
                    guard let self = self else {
                        return
                    }
                    self.countdown -= 1
                    self.updateContinueButton()
                    if self.countdown <= 0 {
                        timer.invalidate()
                    }
                }
            }
        case let .withdraw(_, address, _):
            nameLabel.text = R.string.localizable.pay_withdrawal_title(address.label)
            mixinIDLabel.text = address.fullAddress
            multisigView.isHidden = true
            if !showError {
                payLabel.text = R.string.localizable.withdraw_by_pin()
                if showBiometric {
                    if biometryType == .faceID {
                        biometricButton.setTitle(R.string.localizable.withdraw_use_face(), for: .normal)
                    } else {
                        biometricButton.setTitle(R.string.localizable.withdraw_use_touch(), for: .normal)
                    }
                }
            }
        case let .payment(payment, receivers):
            guard let account = Account.current else {
                break
            }
            multisigView.isHidden = false
            multisigActionView.image = R.image.multisig_sign()
            nameLabel.text = R.string.localizable.multisig_transaction()
            mixinIDLabel.text = payment.memo
            renderMultisigInfo(showError: showError, showBiometric: showBiometric, senders: [UserResponse.createUser(account: account)], receivers: receivers)
        case let .multisig(multisig, senders, receivers):
            multisigView.isHidden = false
            switch multisig.action {
            case MultisigAction.sign.rawValue:
                multisigActionView.image = R.image.multisig_sign()
                nameLabel.text = R.string.localizable.multisig_transaction()
            case MultisigAction.unlock.rawValue:
                multisigActionView.image = R.image.multisig_revoke()
                nameLabel.text = R.string.localizable.multisig_revoke_transaction()
            default:
                break
            }
            mixinIDLabel.text = multisig.memo
            renderMultisigInfo(showError: showError, showBiometric: showBiometric, senders: senders, receivers: receivers)
        }

        assetIconView.setIcon(asset: asset)
        memoLabel.isHidden = memo.isEmpty
        memoPlaceView.isHidden = memo.isEmpty
        memoLabel.text = memo

        dismissButton.isEnabled = true
        if showBigAmountTips {

        } else if let err = error, !err.isEmpty {
            errorContinueAction = .close
            pinView.isHidden = true
            biometricButton.isHidden = true
            successView.isHidden = true
            errorView.isHidden = false
            errorLabel.text = err
        } else {
            resetPinInput()
        }
        return self
    }

    private func updateContinueButton() {
        var title = R.string.localizable.action_continue()
        if countdown > 0 {
            title += " (\(countdown))"
            bigAmountConfirmButton.isEnabled = false
        } else {
            bigAmountConfirmButton.isEnabled = true
        }
        UIView.performWithoutAnimation {
            bigAmountConfirmButton.setTitle(title, for: .normal)
            bigAmountConfirmButton.layoutIfNeeded()
        }
    }

    private func showTransferView(user: UserItem, showError: Bool, showBiometric: Bool) {
        nameLabel.text = Localized.PAY_TRANSFER_TITLE(fullname: user.fullName)
        mixinIDLabel.text = user.identityNumber
        mixinIDLabel.textColor = .accessoryText
        pinView.isHidden = false
        if !showError {
            payLabel.text = R.string.localizable.transfer_by_pin()
            if showBiometric {
                if biometryType == .faceID {
                    biometricButton.setTitle(R.string.localizable.transfer_use_face(), for: .normal)
                } else {
                    biometricButton.setTitle(R.string.localizable.transfer_use_touch(), for: .normal)
                }
            }
        }
    }

    private func renderMultisigInfo(showError: Bool, showBiometric: Bool, senders: [UserResponse], receivers: [UserResponse]) {
        if !showError {
            payLabel.text = R.string.localizable.multisig_by_pin()
            if showBiometric {
                if biometryType == .faceID {
                    biometricButton.setTitle(R.string.localizable.multisig_use_face(), for: .normal)
                } else {
                    biometricButton.setTitle(R.string.localizable.multisig_use_touch(), for: .normal)
                }
            }
        }

        for view in multisigStackView.arrangedSubviews {
            multisigStackView.sendSubviewToBack(view)
        }

        if senders.count > 0 {
            senderViewOne.setImage(user: senders[0])
        }
        if senders.count > 1 {
            senderViewTwo.setImage(user: senders[1])
            senderViewTwo.isHidden = false
        } else {
            senderViewTwo.isHidden = true
        }
        if senders.count > 2 {
            senderMoreLabel.text = "+\(senders.count - 2)"
            senderMoreView.isHidden = false
        } else {
            senderMoreView.isHidden = true
        }
        if senders.count == 1 {
            sendersButtonWidthConstraint.constant = 32
        } else if senders.count == 2 {
            sendersButtonWidthConstraint.constant = 56
        } else {
            sendersButtonWidthConstraint.constant = 80
        }

        if receivers.count > 0 {
            receiverViewOne.setImage(user: receivers[0])
        }
        if receivers.count > 1 {
            receiverViewTwo.setImage(user: receivers[1])
            receiverViewTwo.isHidden = false
        } else {
            receiverViewTwo.isHidden = true
        }
        if receivers.count > 2 {
            receiverMoreLabel.text = "+\(receivers.count - 2)"
            receiverMoreView.isHidden = false
        } else {
            receiverMoreView.isHidden = true
        }
        if receivers.count == 1 {
            receiversButtonWidthConstraint.constant = 32
        } else if receivers.count == 2 {
            receiversButtonWidthConstraint.constant = 56
        } else {
            receiversButtonWidthConstraint.constant = 80
        }
        multisigView.layoutIfNeeded()
    }

    private func resetPinInput() {
        pinField.isHidden = false
        payLabel.isHidden = false
        pinView.isHidden = false
        errorView.isHidden = true
        successView.isHidden = true
        pinField.clear()
        if isAllowBiometricPay {
            if biometryType == .faceID {
                biometricButton.setImage(R.image.ic_pay_face(), for: .normal)
            } else {
                biometricButton.setImage(R.image.ic_pay_touch(), for: .normal)
            }
            biometricButton.isHidden = false
        } else {
            biometricButton.isHidden = true
        }
        pinField.becomeFirstResponder()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()

        if case let .multisig(multisig, _, _) = pinAction! {
            MultisigAPI.shared.cancel(requestId: multisig.requestId) { (_) in }
        }
    }

    override func dismissPopupControllerAnimated() {
        guard !processing else {
            return
        }
        super.dismissPopupControllerAnimated()
        textfield?.becomeFirstResponder()
        onDismiss?()
    }

    @IBAction func errorNextAction(_ sender: Any) {
        guard let continueAction = errorContinueAction else {
            return
        }
        switch continueAction {
        case .retryPin:
            resetPinInput()
        default:
            dismissPopupControllerAnimated()
        }
        errorContinueAction = nil
    }

    @IBAction func sendersAction(_ sender: Any) {
        guard case let .multisig(_, senders, _) = pinAction! else {
            return
        }

        let window = MultisigUsersWindow.instance()
        window.render(users: senders, isSender: true)
        let isKeyboardAppear = self.isKeyboardAppear
        window.onDismiss = {
            self.isMultisigUsersAppear = false
            if isKeyboardAppear {
                self.pinField.becomeFirstResponder()
            }
        }
        window.presentPopupControllerAnimated()

        isMultisigUsersAppear = true
        if isKeyboardAppear {
            pinField.resignFirstResponder()
        }
    }


    @IBAction func receiversAction(_ sender: Any) {
        var users = [UserResponse]()
        switch pinAction! {
        case let .multisig(_, _, receivers):
            users = receivers
        case let .payment(_, receivers):
            users = receivers
        default:
            return
        }
        let window = MultisigUsersWindow.instance()
        window.render(users: users, isSender: false)
        let isKeyboardAppear = self.isKeyboardAppear
        window.onDismiss = {
            self.isMultisigUsersAppear = false
            if isKeyboardAppear {
                self.pinField.becomeFirstResponder()
            }
        }
        window.presentPopupControllerAnimated()

        isMultisigUsersAppear = true
        if isKeyboardAppear {
            pinField.resignFirstResponder()
        }
    }


    @IBAction func biometricAction(_ sender: Any) {
        guard isAllowBiometricPay else {
            return
        }

        let prompt = Localized.WALLET_BIOMETRIC_PAY_PROMPT(biometricType: biometryType.localizedName)
        DispatchQueue.global().async { [weak self] in
            guard let pin = Keychain.shared.getPIN(prompt: prompt) else {
                return
            }
            DispatchQueue.main.async {
                self?.isAutoFillPIN = true
                self?.pinField.clear()
                self?.pinField.insertText(pin)
            }
        }
    }

    @IBAction func dismissAction(_ sender: Any) {
        if isKeyboardAppear && textfield == nil {
            pinField.resignFirstResponder()
        } else {
            dismissPopupControllerAnimated()
        }
    }

    @IBAction func bigAmountContinueAction(_ sender: Any) {
        guard case let .transfer(_, user, _) = pinAction! else {
            return
        }
        bigAmountTipsView.isHidden = true
        bigAmountTitleSpaceView.isHidden = true
        bigAmountIconSpaceView.isHidden = true
        showTransferView(user: user, showError: false, showBiometric: isAllowBiometricPay)
        resetPinInput()
    }


    @IBAction func dismissTipsAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    static func instance() -> PayWindow {
        return Bundle.main.loadNibNamed("PayWindow", owner: nil, options: nil)?.first as! PayWindow
    }

}

extension PayWindow {

    @objc func keyboardWillAppear(_ sender: Notification) {
        isKeyboardAppear = true
        guard let info = sender.userInfo, isShowing else {
            return
        }
        guard let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
            return
        }
        guard let endKeyboardRect = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        guard let animation = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue else {
            return
        }
        let options = UIView.AnimationOptions(rawValue: UInt(animation << 16))
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.contentBottomConstraint.constant = endKeyboardRect.height
            self.layoutIfNeeded()
        }, completion: nil)
    }

    @objc func keyboardWillDisappear(_ sender: Notification) {
        isKeyboardAppear = false
        guard let info = sender.userInfo, isShowing, !isMultisigUsersAppear else {
            return
        }
        guard let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
            return
        }
        guard let animation = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue else {
            return
        }
        let options = UIView.AnimationOptions(rawValue: UInt(animation << 16))

        if successView.isHidden && errorContinueAction == nil {
            UIView.animate(withDuration: 5, delay: 0, options: options, animations: {
                self.alpha = 0
                self.popupView.center = self.getAnimationStartPoint()
            }, completion: { (_) in
                self.isShowing = false
                self.removeFromSuperview()
            })
        } else {
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                self.contentBottomConstraint.constant = 0
                self.layoutIfNeeded()
            }, completion: nil)
        }
    }

}

extension PayWindow: PinFieldDelegate {

    func inputFinished(pin: String) {
        transferAction(pin: pin)
    }

    private func failedHandler(error: APIError) {
        let errorMsg = error.code == 429 ? R.string.localizable.wallet_password_too_many_requests() : error.localizedDescription
        switch error.code {
        case 20118, 20119:
            errorContinueAction = .retryPin
        case 20120, 20117:
            errorContinueAction = .changeAmount
        default:
            errorContinueAction = .close
        }
        failedHandler(errorMsg: errorMsg)
    }

    private func failedHandler(errorMsg: String) {
        guard let continueAction = errorContinueAction else {
            return
        }
        switch continueAction {
        case .retryPin:
            errorContinueButton.setTitle(R.string.localizable.action_try_again(), for: .normal)
        case .changeAmount:
            errorContinueButton.setTitle(R.string.localizable.wallet_withdrawal_change_amount(), for: .normal)
        case .close:
            errorContinueButton.setTitle(R.string.localizable.dialog_button_ok(), for: .normal)
        }
        processing = false
        loadingView.stopAnimating()
        dismissButton.isEnabled = true
        errorLabel.text = errorMsg
        biometricButton.isHidden = true
        pinView.isHidden = true
        successView.isHidden = true
        errorView.isHidden = false
        pinField.resignFirstResponder()
    }

    private func successHandler() {
        if !isAutoFillPIN {
            AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
        }
        loadingView.stopAnimating()
        pinView.isHidden = true
        successView.isHidden = false
        playSuccessSound()
        delayDismissWindow()
    }

    private func transferAction(pin: String) {
        guard !processing else {
            return
        }
        processing = true
        let pinAction: PinAction = self.pinAction!
        let assetId = asset.assetId
        dismissButton.isEnabled = false
        if !biometricButton.isHidden {
            biometricButton.isHidden = true
        }
        pinField.isHidden = true
        payLabel.isHidden = true
        loadingView.startAnimating()

        let completion = { [weak self](result: APIResult<Snapshot>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case let .success(snapshot):
                switch pinAction {
                case .transfer, .payment:
                    AppGroupUserDefaults.User.hasPerformedTransfer = true
                    AppGroupUserDefaults.Wallet.defaultTransferAssetId = assetId
                case let .withdraw(_,address,_):
                    AppGroupUserDefaults.Wallet.withdrawnAddressIds[address.addressId] = true
                    ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: snapshot.assetId))
                default:
                    break
                }
                SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: [snapshot])
                weakSelf.successHandler()
            case let .failure(error):
                weakSelf.failedHandler(error: error)
            }
        }

        let generalizedAmount: String
        if let decimalSeparator = Locale.current.decimalSeparator, decimalSeparator != "." {
            generalizedAmount = amount.replacingOccurrences(of: decimalSeparator, with: ".")
        } else {
            generalizedAmount = amount
        }

        switch pinAction {
        case let .transfer(trackId, user, _):
            AssetAPI.shared.transfer(assetId: assetId, opponentId: user.userId, amount: generalizedAmount, memo: memo, pin: pin, traceId: trackId, completion: completion)
        case let .payment(payment, _):
            let transactionRequest = RawTransactionRequest(assetId: payment.assetId, opponentMultisig: OpponentMultisig(receivers: payment.receivers, threshold: payment.threshold), amount: payment.amount, pin: "", traceId: payment.traceId, memo: payment.memo)
            AssetAPI.shared.transactions(transactionRequest: transactionRequest, pin: pin, completion: completion)
        case let .withdraw(trackId, address, fromWeb):
            if fromWeb {
                AssetAPI.shared.payments(assetId: asset.assetId, addressId: address.addressId, amount: amount, traceId: trackId) { [weak self](result) in
                    guard let weakSelf = self else {
                        return
                    }
                    switch result {
                    case let .success(payment):
                        guard payment.status != PaymentStatus.paid.rawValue else {
                            weakSelf.errorContinueAction = .close
                            weakSelf.failedHandler(errorMsg: Localized.TRANSFER_PAID)
                            return
                        }
                        WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: weakSelf.memo), completion: completion)
                    case let .failure(error):
                        weakSelf.failedHandler(error: error)
                    }
                }
            } else {
                WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo), completion: completion)
            }
        case let .multisig(multisig, _, _):
            let multisigCompletion = { [weak self](result: APIResult<EmptyResponse>) in
                guard let weakSelf = self else {
                    return
                }
                switch result {
                case .success:
                    weakSelf.successHandler()
                case let .failure(error):
                    weakSelf.failedHandler(error: error)
                }
            }
            switch multisig.action {
            case MultisigAction.sign.rawValue:
                MultisigAPI.shared.sign(requestId: multisig.requestId, pin: pin, completion: multisigCompletion)
            case MultisigAction.unlock.rawValue:
                MultisigAPI.shared.unlock(requestId: multisig.requestId, pin: pin, completion: multisigCompletion)
            default:
                break
            }
        }
    }

    private func delayDismissWindow() {
        pinField.resignFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.processing = false
            weakSelf.dismissPopupControllerAnimated()

            guard let navigation = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigation.viewControllers

            switch weakSelf.pinAction! {
            case let .transfer(_, user, fromWeb):
                guard !fromWeb else {
                    return
                }
                if (viewControllers.first(where: { $0 is ConversationViewController }) as? ConversationViewController)?.dataSource.ownerUser?.userId == user.userId {
                    while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
                        viewControllers.removeLast()
                    }
                } else {
                    while (viewControllers.count > 0 && !(viewControllers.last is HomeViewController)) {
                        viewControllers.removeLast()
                    }
                    viewControllers.append(ConversationViewController.instance(ownerUser: user))
                }
                navigation.setViewControllers(viewControllers, animated: true)
            case let .withdraw(_, _, fromWeb):
                guard !fromWeb else {
                    return
                }
                while (viewControllers.count > 0 && !(viewControllers.last is HomeViewController)) {
                    if let _ = (viewControllers.last as? ContainerViewController)?.viewController as? AssetViewController {
                        break
                    }
                    viewControllers.removeLast()
                }
                navigation.setViewControllers(viewControllers, animated: true)
            case .multisig:
                break
            case .payment:
                break
            }
        }
    }

    private func playSuccessSound() {
        if soundId == 0 {
            guard let path = Bundle.main.path(forResource: "payment_success", ofType: "caf") else {
                return
            }
            AudioServicesCreateSystemSoundID(URL(fileURLWithPath: path) as CFURL, &soundId)
        }
        AudioServicesPlaySystemSound(soundId)
    }
}
