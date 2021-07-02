import UIKit
import Foundation
import LocalAuthentication
import AudioToolbox
import Alamofire
import MixinServices

class PayWindow: BottomSheetView {

    enum PinAction {
        case payment(payment: PaymentCodeResponse, receivers: [UserItem])
        case transfer(trackId: String, user: UserItem, fromWeb: Bool)
        case withdraw(trackId: String, address: Address, chainAsset: AssetItem, fromWeb: Bool)
        case multisig(multisig: MultisigResponse, senders: [UserItem], receivers: [UserItem])
    }

    enum ErrorContinueAction {
        case retryPin
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
    @IBOutlet weak var enableBiometricAuthButton: UIButton!
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

    @IBOutlet weak var sendersButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var receiversButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var successViewHeightConstraint: NSLayoutConstraint!
    
    private lazy var biometricAuthQueue = DispatchQueue(label: "one.mixin.messenger.PayWindow.BioAuth")
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
    private var isDelayDismissCancelled = false
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

    var onDismiss: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        pinField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear), name: UIResponder.keyboardWillHideNotification, object: nil)
        switch ScreenHeight.current {
        case .short:
            mixinIDLabel.numberOfLines = 1
        case .medium, .long:
            mixinIDLabel.numberOfLines = 3
        case .extraLong:
            mixinIDLabel.numberOfLines = 5
        }
    }

    func render(asset: AssetItem, action: PinAction, amount: String, memo: String, error: String? = nil, fiatMoneyAmount: String? = nil, textfield: UITextField? = nil) -> PayWindow {
        self.asset = asset
        self.amount = amount
        self.memo = memo
        self.pinAction = action
        self.textfield = textfield

        let amountToken = CurrencyFormatter.localizedString(from: amount, locale: .current, format: .precision, sign: .whenNegative, symbol: .custom(asset.symbol)) ?? amount
        let amountExchange = CurrencyFormatter.localizedPrice(price: amount, priceUsd: asset.priceUsd)
        if let fiatMoneyAmount = fiatMoneyAmount {
            amountLabel.text = fiatMoneyAmount + " " + Currency.current.code
            amountExchangeLabel.text = amountToken
        } else {
            amountLabel.text = amountToken
            amountExchangeLabel.text = amountExchange
        }

        let showError = !(error?.isEmpty ?? true)
        let showBiometric = isAllowBiometricPay
        switch pinAction! {
        case let .transfer(_, user, _):
            multisigView.isHidden = true
            nameLabel.text = Localized.PAY_TRANSFER_TITLE(fullname: user.fullName)
            mixinIDLabel.text = user.isCreatedByMessenger ? user.identityNumber : user.userId
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
        case let .withdraw(_, address, chainAsset, _):
            multisigView.isHidden = true
            nameLabel.text = R.string.localizable.pay_withdrawal_title(address.label)
            mixinIDLabel.text = address.fullAddress
            let feeToken = CurrencyFormatter.localizedString(from: address.fee, locale: .current, format: .precision, sign: .whenNegative, symbol: .custom(chainAsset.symbol)) ?? address.fee
            let feeExchange = CurrencyFormatter.localizedPrice(price: address.fee, priceUsd: chainAsset.priceUsd)
            if let fiatMoneyAmount = fiatMoneyAmount {
                amountExchangeLabel.text = R.string.localizable.pay_withdrawal_memo(amountToken, "≈ " + Currency.current.symbol + fiatMoneyAmount, feeToken, feeExchange)
            } else {
                amountExchangeLabel.text = R.string.localizable.pay_withdrawal_memo(amountToken, amountExchange, feeToken, feeExchange)
            }

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
            guard let account = LoginManager.shared.account else {
                break
            }
            multisigView.isHidden = false
            multisigActionView.image = R.image.multisig_sign()
            nameLabel.text = R.string.localizable.multisig_transaction()
            mixinIDLabel.text = payment.memo
            renderMultisigInfo(showError: showError, showBiometric: showBiometric, senders: [UserItem.createUser(from: account)], receivers: receivers)
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
        if let err = error, !err.isEmpty {
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

    private func renderMultisigInfo(showError: Bool, showBiometric: Bool, senders: [UserItem], receivers: [UserItem]) {
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
            senderViewOne.setImage(with: senders[0])
        }
        if senders.count > 1 {
            senderViewTwo.setImage(with: senders[1])
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
            receiverViewOne.setImage(with: receivers[0])
        }
        if receivers.count > 1 {
            receiverViewTwo.setImage(with: receivers[1])
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
            MultisigAPI.cancel(requestId: multisig.requestId) { (_) in }
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
        var users = [UserItem]()
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
        biometricAuthQueue.async { [weak self] in
            DispatchQueue.main.sync {
                ScreenLockManager.shared.hasOtherBiometricAuthInProgress = true
            }
            guard let pin = Keychain.shared.getPIN(prompt: prompt) else {
                DispatchQueue.main.sync {
                    ScreenLockManager.shared.hasOtherBiometricAuthInProgress = false
                }
                return
            }
            DispatchQueue.main.sync {
                ScreenLockManager.shared.hasOtherBiometricAuthInProgress = false
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

    @IBAction func dismissTipsAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    @IBAction func enableBiometricAuth(_ sender: Any) {
        pinField.resignFirstResponder()
        isDelayDismissCancelled = true
        processing = false
        dismissPopupControllerAnimated()
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        var viewControllers = navigationController.viewControllers.filter { (viewController) -> Bool in
            if let container = viewController as? ContainerViewController {
                return !(container.viewController is TransferOutViewController)
            } else {
                return true
            }
        }
        viewControllers.append(PinSettingsViewController.instance())
        navigationController.setViewControllers(viewControllers, animated: true)
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

    private func failedHandler(error: MixinAPIError) {
        PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
            guard let self = self else {
                return
            }
            switch error {
            case .malformedPin, .incorrectPin, .insufficientPool, .internalServerError:
                self.errorContinueAction = .retryPin
            default:
                self.errorContinueAction = .close
            }
            self.failedHandler(errorMsg: description)
        }
    }

    private func failedHandler(errorMsg: String) {
        guard let continueAction = errorContinueAction else {
            return
        }
        switch continueAction {
        case .retryPin:
            errorContinueButton.setTitle(R.string.localizable.action_try_again(), for: .normal)
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
        var delay: TimeInterval = 2
        if isAllowBiometricPay || biometryType == .none {
            enableBiometricAuthButton.isHidden = true
            successViewHeightConstraint.constant = 119
        } else {
            delay = 3
            switch biometryType {
            case .touchID:
                let title = R.string.localizable.wallet_store_encrypted_pin_tip(R.string.localizable.wallet_touch_id())
                UIView.performWithoutAnimation {
                    enableBiometricAuthButton.setImage(R.image.ic_pay_touch(), for: .normal)
                    enableBiometricAuthButton.setTitle(title, for: .normal)
                    enableBiometricAuthButton.layoutIfNeeded()
                }
            case .faceID:
                let title = R.string.localizable.wallet_store_encrypted_pin_tip(R.string.localizable.wallet_face_id())
                UIView.performWithoutAnimation {
                    enableBiometricAuthButton.setImage(R.image.ic_pay_face(), for: .normal)
                    enableBiometricAuthButton.setTitle(title, for: .normal)
                    enableBiometricAuthButton.layoutIfNeeded()
                }
            case .none:
                break
            }
            enableBiometricAuthButton.isHidden = false
            successViewHeightConstraint.constant = 119 + 10 + enableBiometricAuthButton.frame.height
        }
        successView.isHidden = false
        playSuccessSound()
        delayDismissWindow(delay: delay)
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

        var trace: Trace?
        let completion = { [weak self] (result: MixinAPI.Result<Snapshot>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case let .success(snapshot):
                if let trace = trace {
                    TraceDAO.shared.updateSnapshot(traceId: trace.traceId, snapshotId: snapshot.snapshotId)
                }
                switch pinAction {
                case .transfer, .payment:
                    AppGroupUserDefaults.User.hasPerformedTransfer = true
                    AppGroupUserDefaults.Wallet.defaultTransferAssetId = assetId
                case let .withdraw(_,address,_,_):
                    AppGroupUserDefaults.Wallet.withdrawnAddressIds[address.addressId] = true
                    ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: snapshot.assetId))
                default:
                    break
                }
                SnapshotDAO.shared.saveSnapshots(snapshots: [snapshot])
                weakSelf.successHandler()
            case let .failure(error):
                switch error {
                case .insufficientBalance, .malformedPin, .incorrectPin, .transferAmountTooSmall, .insufficientFee, .chainNotInSync:
                    if let trace = trace {
                        TraceDAO.shared.deleteTrace(traceId: trace.traceId)
                    }
                default:
                    break
                }
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
            trace = Trace(traceId: trackId, assetId: assetId, amount: generalizedAmount, opponentId: user.userId, destination: nil, tag: nil)
            TraceDAO.shared.saveTrace(trace: trace)
            PaymentAPI.transfer(assetId: assetId, opponentId: user.userId, amount: generalizedAmount, memo: memo, pin: pin, traceId: trackId, completion: completion)
        case let .payment(payment, _):
            let transactionRequest = RawTransactionRequest(assetId: payment.assetId, opponentMultisig: OpponentMultisig(receivers: payment.receivers, threshold: payment.threshold), amount: payment.amount, pin: "", traceId: payment.traceId, memo: payment.memo)
            PaymentAPI.transactions(transactionRequest: transactionRequest, pin: pin, completion: completion)
        case let .withdraw(trackId, address, _, _):
            trace = Trace(traceId: trackId, assetId: assetId, amount: generalizedAmount, opponentId: nil, destination: address.destination, tag: address.tag)
            TraceDAO.shared.saveTrace(trace: trace)
            WithdrawalAPI.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo), completion: completion)
        case let .multisig(multisig, _, _):
            let multisigCompletion = { [weak self] (result: MixinAPI.Result<Empty>) in
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
                MultisigAPI.sign(requestId: multisig.requestId, pin: pin, completion: multisigCompletion)
            case MultisigAction.unlock.rawValue:
                MultisigAPI.unlock(requestId: multisig.requestId, pin: pin, completion: multisigCompletion)
            default:
                break
            }
        }
    }

    private func delayDismissWindow(delay: TimeInterval = 2) {
        pinField.resignFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let weakSelf = self, !weakSelf.isDelayDismissCancelled else {
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
            case let .withdraw(_, _, _, fromWeb):
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

extension PayWindow {

    static func checkPay(traceId: String, asset: AssetItem, action: PayWindow.PinAction, opponentId: String? = nil, destination: String? = nil, tag: String? = nil, addressId: String? = nil, amount: String, fiatMoneyAmount: String? = nil, memo: String, fromWeb: Bool, completion: @escaping AssetConfirmationWindow.CompletionHandler) {

        if fromWeb {
            var response: MixinAPI.Result<PaymentResponse>?
            if let opponentId = opponentId {
                response = PaymentAPI.payments(assetId: asset.assetId, opponentId: opponentId, amount: amount, traceId: traceId)
            } else if let addressId = addressId {
                response = PaymentAPI.payments(assetId: asset.assetId, addressId: addressId, amount: amount, traceId: traceId)
            }

            if let result = response {
                switch result {
                case let .success(payment):
                    if payment.status == PaymentStatus.paid.rawValue {
                        DispatchQueue.main.async {
                            PayWindow.instance().render(asset: asset, action: action, amount: amount, memo: memo, error: R.string.localizable.transfer_paid(), fiatMoneyAmount: fiatMoneyAmount).presentPopupControllerAnimated()
                        }
                        completion(false, nil)
                        return
                    }
                case let .failure(error):
                    completion(false, error.localizedDescription)
                    return
                }
            }
        }

        let checkAmountAction = {
            switch action {
            case let .transfer(_, user, _):
                let fiatMoneyValue = amount.doubleValue * asset.priceUsd.doubleValue * Currency.current.rate
                let threshold = LoginManager.shared.account?.transfer_confirmation_threshold ?? 0
                if threshold != 0 && fiatMoneyValue >= threshold {
                    DispatchQueue.main.async {
                        BigAmountConfirmationWindow.instance().render(asset: asset, user: user, amount: amount, memo: memo, completion: completion).presentPopupControllerAnimated()
                    }
                    return
                }
            case let .withdraw(_, address, _, _):
                if let amount = Decimal(string: amount, locale: .current), let dust = Decimal(string: address.dust, locale: .us), amount < dust {
                    completion(false, R.string.localizable.withdrawal_minimum_amount(address.dust, asset.symbol))
                    return
                }

                if AppGroupUserDefaults.Wallet.withdrawnAddressIds[address.addressId] == nil && amount.doubleValue * asset.priceUsd.doubleValue * Currency.current.rate > 10 {
                    DispatchQueue.main.async {
                        WithdrawalTipWindow.instance().render(asset: asset, completion: completion).presentPopupControllerAnimated()
                    }
                    return
                }
            default:
                break
            }

            completion(true, nil)
        }

        if AppGroupUserDefaults.User.duplicateTransferConfirmation, let trace = TraceDAO.shared.getTrace(assetId: asset.assetId, amount: amount, opponentId: opponentId, destination: destination, tag: tag, createdAt: Date().within6Hours().toUTCString()) {

            if let snapshotId = trace.snapshotId, !snapshotId.isEmpty {
                DispatchQueue.main.async {
                    DuplicateConfirmationWindow.instance().render(traceCreatedAt: trace.createdAt, asset: asset, action: action, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount) { (isContinue, errorMsg) in
                        if isContinue {
                            checkAmountAction()
                        } else {
                            completion(false, errorMsg)
                        }
                    }.presentPopupControllerAnimated()
                }
                return
            } else {
                switch SnapshotAPI.trace(traceId: traceId) {
                case let .success(snapshot):
                    TraceDAO.shared.updateSnapshot(traceId: traceId, snapshotId: snapshot.snapshotId)
                    DispatchQueue.main.async {
                        DuplicateConfirmationWindow.instance().render(traceCreatedAt: snapshot.createdAt, asset: asset, action: action, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount) { (isContinue, errorMsg) in
                            if isContinue {
                                checkAmountAction()
                            } else {
                                completion(false, errorMsg)
                            }
                        }.presentPopupControllerAnimated()
                    }
                    return
                case .failure(.notFound):
                    break
                case let .failure(error):
                    completion(false, error.localizedDescription)
                    return
                }
            }
        }

        checkAmountAction()
    }

}
