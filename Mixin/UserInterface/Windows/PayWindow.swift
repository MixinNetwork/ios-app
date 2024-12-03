import UIKit
import Foundation
import LocalAuthentication
import AudioToolbox
import Alamofire
import MixinServices

class PayWindow: BottomSheetView {

    enum PinAction {
        case payment(payment: PaymentCodeResponse, receivers: [UserItem])
        case transfer(trackId: String, user: UserItem, fromWeb: Bool, returnTo: URL?)
        case multisig(multisig: MultisigResponse, senders: [UserItem], receivers: [UserItem])
        case collectible(collectible: CollectibleResponse, senders: [UserItem], receivers: [UserItem])
    }

    enum ErrorContinueAction {
        case retryPin
        case close
    }

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var mixinIDPlaceView: UIView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var memoPlaceView: UIView!
    @IBOutlet weak var assetIconView: BadgeIconView!
    @IBOutlet weak var successView: UIView!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var paySuccessImageView: UIImageView!
    @IBOutlet weak var enableBiometricAuthButton: UIButton!
    @IBOutlet weak var biometricButton: UIButton!
    @IBOutlet weak var multisigView: UIView!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var pinView: UIView!
    @IBOutlet weak var errorContinueButton: RoundedButton!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var stayInMixinButton: UIButton!
    @IBOutlet weak var successButton: RoundedButton!
    
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
    @IBOutlet weak var collectibleView: UIStackView!
    @IBOutlet weak var collectibleImageView: UIImageView!
    
    @IBOutlet weak var sendersButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var receiversButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var successViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var amountLabelPlaceHeightConstraint: ScreenHeightCompatibleLayoutConstraint!
    @IBOutlet weak var resultViewPlaceHeightConstraint: ScreenHeightCompatibleLayoutConstraint!
    @IBOutlet weak var pinViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var successButtonBottomConstraint: NSLayoutConstraint!
    
    private lazy var biometricAuthQueue = DispatchQueue(label: "one.mixin.messenger.PayWindow.BioAuth")
    private lazy var context = LAContext()
    private weak var textfield: UITextField?

    private var pinAction: PinAction!
    private var errorContinueAction: ErrorContinueAction?
    private var asset: AssetItem?
    private var amount = ""
    private var memo = ""
    private var fiatMoneyAmount: String?
    private var amountToken = ""
    private var amountExchange = ""
    private var soundId: SystemSoundID = 0
    private var isAutoFillPIN = false
    private var processing = false
    private var isKeyboardAppear = false
    private var isMultisigUsersAppear = false
    private var isAllowBiometricPay: Bool {
        guard AppGroupUserDefaults.Wallet.payWithBiometricAuthentication else {
            return false
        }
        guard let date = AppGroupUserDefaults.Wallet.lastPINVerifiedDate, -date.timeIntervalSinceNow < AppGroupUserDefaults.Wallet.biometricPaymentExpirationInterval else {
            return false
        }
        guard BiometryType.payment != .none else {
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

    func render(
        asset: AssetItem? = nil,
        token: CollectibleToken? = nil,
        action: PinAction,
        amount: String,
        isAmountLocalized: Bool = true,
        memo: String,
        error: String? = nil,
        fiatMoneyAmount: String? = nil,
        textfield: UITextField? = nil
    ) -> PayWindow {
        self.asset = asset
        self.amount = amount
        self.memo = memo
        self.pinAction = action
        self.textfield = textfield
        self.fiatMoneyAmount = fiatMoneyAmount
        if let asset = asset {
            assetIconView.isHidden = false
            collectibleView.isHidden = true
            tokenNameLabel.isHidden = true
            mixinIDPlaceView.isHidden = false
            amountLabelPlaceHeightConstraint.constant = 10
            amountToken = CurrencyFormatter.localizedString(from: amount,
                                                            locale: isAmountLocalized ? .current : .us,
                                                            format: .precision,
                                                            sign: .whenNegative,
                                                            symbol: .custom(asset.symbol)) ?? amount
            amountExchange = CurrencyFormatter.localizedPrice(price: amount, priceUsd: asset.priceUsd)
            if let fiatMoneyAmount = fiatMoneyAmount {
                amountLabel.text = fiatMoneyAmount + " " + Currency.current.code
                amountExchangeLabel.text = amountToken
            } else {
                amountLabel.text = amountToken
                amountExchangeLabel.text = amountExchange
            }
            switch pinAction! {
            case let .transfer(_, user, _, _):
                multisigView.isHidden = true
                nameLabel.text = R.string.localizable.transfer_to(user.fullName)
                mixinIDLabel.text = user.isCreatedByMessenger ? user.identityNumber : user.userId
                mixinIDLabel.textColor = R.color.text_tertiary()!
                pinView.isHidden = false
            case let .payment(payment, receivers):
                guard let account = LoginManager.shared.account else {
                    break
                }
                multisigView.isHidden = false
                multisigActionView.image = R.image.multisig_sign()
                nameLabel.text = R.string.localizable.multisig_transaction()
                mixinIDLabel.text = payment.memo
                renderMultisigInfo(senders: [UserItem.createUser(from: account)], receivers: receivers)
            case let .multisig(multisig, senders, receivers):
                multisigView.isHidden = false
                switch MultisigAction(string: multisig.action) {
                case .sign:
                    multisigActionView.image = R.image.multisig_sign()
                    nameLabel.text = R.string.localizable.multisig_transaction()
                case .revoke:
                    multisigActionView.image = R.image.multisig_revoke()
                    nameLabel.text = R.string.localizable.revoke_multisig_transaction()
                default:
                    break
                }
                mixinIDLabel.text = multisig.memo
                renderMultisigInfo(senders: senders, receivers: receivers)
            case .collectible:
                break
            }
            assetIconView.setIcon(asset: asset)
            memoLabel.isHidden = memo.isEmpty
            memoPlaceView.isHidden = memo.isEmpty
            memoLabel.text = memo
        } else if let token = token, case let .collectible(collectible, senders, receivers) = action {
            multisigView.isHidden = false
            assetIconView.isHidden = true
            collectibleView.isHidden = false
            tokenNameLabel.isHidden = false
            memoLabel.isHidden = true
            memoPlaceView.isHidden = false
            mixinIDPlaceView.isHidden = true
            amountLabelPlaceHeightConstraint.constant = 6
            switch collectible.action {
            case CollectibleAction.sign.rawValue:
                multisigActionView.image = R.image.multisig_sign()
                nameLabel.text = R.string.localizable.transfer()
            case CollectibleAction.unlock.rawValue:
                multisigActionView.image = R.image.multisig_revoke()
                nameLabel.text = R.string.localizable.revoke_multisig_transaction()
            default:
                break
            }
            mixinIDLabel.text = nil
            amountLabel.text = token.meta.groupName
            amountExchangeLabel.text = R.string.localizable.collectible_token_id(token.tokenKey)
            tokenNameLabel.text = token.meta.tokenName
            collectibleImageView.sd_setImage(with: URL(string: token.meta.iconUrl))
            renderMultisigInfo(senders: senders, receivers: receivers)
        }
        dismissButton.isEnabled = true
        if let error, !error.isEmpty {
            resultViewPlaceHeightConstraint.constant = 30
            errorContinueAction = .close
            pinView.isHidden = true
            biometricButton.isHidden = true
            successView.isHidden = true
            errorView.isHidden = false
            errorLabel.text = error
        } else {
            resetPinInput()
            if isAllowBiometricPay {
                biometricButton.setTitle(R.string.localizable.use_biometry(BiometryType.payment.localizedName), for: .normal)
                pinViewHeightConstraint.constant = 56
            } else {
                pinViewHeightConstraint.constant = 60
            }
        }
        return self
    }

    private func renderMultisigInfo(senders: [UserItem], receivers: [UserItem]) {
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
        pinView.isHidden = false
        errorView.isHidden = true
        successView.isHidden = true
        pinField.clear()
        let needsInitializeTIP = TIP.status == .needsInitialize
        if isAllowBiometricPay {
            if BiometryType.payment == .faceID {
                biometricButton.setImage(R.image.ic_pay_face(), for: .normal)
            } else {
                biometricButton.setImage(R.image.ic_pay_touch(), for: .normal)
            }
            biometricButton.isHidden = false
            resultViewPlaceHeightConstraint.constant = needsInitializeTIP ? 30 : 20
        } else {
            biometricButton.isHidden = true
            resultViewPlaceHeightConstraint.constant = needsInitializeTIP ? 10 : 0
        }
        pinField.becomeFirstResponder()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()

        if case let .multisig(multisig, _, _) = pinAction! {
            MultisigAPI.cancel(requestId: multisig.requestId) { (_) in }
        } else if case let .collectible(collectible, _, _) = pinAction! {
            CollectibleAPI.cancel(requestId: collectible.requestId) { (_) in }
        }
    }

    override func dismissPopupController(animated: Bool) {
        guard !processing else {
            return
        }
        super.dismissPopupController(animated: animated)
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
            dismissPopupController(animated: true)
        }
        errorContinueAction = nil
    }

    @IBAction func sendersAction(_ sender: Any) {
        let users: [UserItem]?
        if case let .multisig(_, senders, _) = pinAction! {
            users = senders
        } else if case let .collectible(_, senders, _) = pinAction! {
            users = senders
        } else {
            users = nil
        }
        guard let users = users else {
            return
        }
        let window = MultisigUsersWindow.instance()
        window.render(users: users, isSender: true)
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
        case let .collectible(_, _, receivers):
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

        let prompt = R.string.localizable.authorize_payment_via(BiometryType.payment.localizedName)
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
            dismissPopupController(animated: true)
        }
    }

    @IBAction func dismissTipsAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
    @IBAction func enableBiometricAuth(_ sender: Any) {
        pinField.resignFirstResponder()
        processing = false
        dismissPopupController(animated: true)
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        var viewControllers = navigationController.viewControllers.filter { (viewController) -> Bool in
            !(viewController is LegacyTransferOutViewController)
        }
        viewControllers.append(PinSettingsViewController())
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    @IBAction func successAction(_ sender: Any) {
        if case let .transfer(_, _, _, returnTo) = pinAction!, let url = returnTo {
            UIApplication.shared.open(url)
        }
        dismissWindow()
    }
    
    @IBAction func stayInMixinAction(_ sender: Any) {
        dismissWindow()
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

    private func updateAmountExchangeForWithdraw(fee: String, feeAsset: AssetItem) -> String {
        let feeToken = CurrencyFormatter.localizedString(from: fee, locale: .us, format: .precision, sign: .whenNegative, symbol: .custom(feeAsset.symbol)) ?? fee
        let feeExchange = CurrencyFormatter.localizedPrice(price: fee, priceUsd: feeAsset.priceUsd)
        if let fiatMoneyAmount = fiatMoneyAmount {
            amountExchangeLabel.text = R.string.localizable.pay_withdrawal_memo(amountToken, "≈ " + Currency.current.symbol + fiatMoneyAmount, feeToken, feeExchange)
        } else {
            amountExchangeLabel.text = R.string.localizable.pay_withdrawal_memo(amountToken, amountExchange, feeToken, feeExchange)
        }
        return feeToken
    }
    
    private func failedHandler(error: MixinAPIError) {
        PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
            guard let self = self else {
                return
            }
            let message = description
            switch error {
            case .malformedPin, .incorrectPin, .insufficientPool, .internalServerError:
                self.errorContinueAction = .retryPin
                self.failedHandler(errorMsg: message)
            case .insufficientFee:
                self.errorContinueAction = .close
                self.failedHandler(errorMsg: message)
            default:
                self.errorContinueAction = .close
                self.failedHandler(errorMsg: message)
            }
        }
    }

    private func failedHandler(errorMsg: String) {
        guard let continueAction = errorContinueAction else {
            return
        }
        switch continueAction {
        case .retryPin:
            errorContinueButton.setTitle(R.string.localizable.try_again(), for: .normal)
        case .close:
            errorContinueButton.setTitle(R.string.localizable.ok(), for: .normal)
        }
        processing = false
        loadingView.stopAnimating()
        dismissButton.isEnabled = true
        errorLabel.text = errorMsg
        biometricButton.isHidden = true
        pinView.isHidden = true
        successView.isHidden = true
        errorView.isHidden = false
        resultViewPlaceHeightConstraint.constant = 30
        pinField.resignFirstResponder()
    }

    private func successHandler() {
        if !isAutoFillPIN {
            AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
        }
        loadingView.stopAnimating()
        pinView.isHidden = true
        dismissButton.isHidden = true
        resultViewPlaceHeightConstraint.constant = 30
        var successViewHeight = 171.0
        if case let .transfer(_, _, _, returnTo) = pinAction!, returnTo != nil {
            UIView.performWithoutAnimation {
                successButton.setTitle(R.string.localizable.back_to_merchant(), for: .normal)
                successButton.layoutIfNeeded()
            }
            stayInMixinButton.isHidden = false
            enableBiometricAuthButton.isHidden = true
            successViewHeight = successViewHeight + successButtonBottomConstraint.constant + stayInMixinButton.frame.height
        } else {
            if isAllowBiometricPay || BiometryType.payment == .none {
                enableBiometricAuthButton.isHidden = true
            } else {
                switch BiometryType.payment {
                case .touchID:
                    let title = R.string.localizable.enable_pay_confirmation(R.string.localizable.touch_id())
                    UIView.performWithoutAnimation {
                        enableBiometricAuthButton.setImage(R.image.ic_pay_touch(), for: .normal)
                        enableBiometricAuthButton.setTitle(title, for: .normal)
                        enableBiometricAuthButton.layoutIfNeeded()
                    }
                case .faceID:
                    let title = R.string.localizable.enable_pay_confirmation(R.string.localizable.face_id())
                    UIView.performWithoutAnimation {
                        enableBiometricAuthButton.setImage(R.image.ic_pay_face(), for: .normal)
                        enableBiometricAuthButton.setTitle(title, for: .normal)
                        enableBiometricAuthButton.layoutIfNeeded()
                    }
                case .none:
                    break
                }
                enableBiometricAuthButton.isHidden = false
                successViewHeight = successViewHeight + 24 + enableBiometricAuthButton.frame.height
            }
            stayInMixinButton.isHidden = true
        }
        successViewHeightConstraint.constant = successViewHeight
        successView.isHidden = false
        playSuccessSound()
        pinField.resignFirstResponder()
    }

    private func transferAction(pin: String) {
        guard !processing else {
            return
        }
        processing = true
        let pinAction: PinAction = self.pinAction!
        dismissButton.isEnabled = false
        if !biometricButton.isHidden {
            biometricButton.isHidden = true
        }
        pinField.isHidden = true
        loadingView.startAnimating()
        
        let assetId = asset?.assetId ?? ""
        var trace: Trace?
        let completion = { [weak self] (result: MixinAPI.Result<Snapshot>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case let .success(snapshot):
                switch pinAction {
                case .transfer, .payment:
                    AppGroupUserDefaults.User.hasPerformedTransfer = true
                    AppGroupUserDefaults.Wallet.defaultTransferAssetId = assetId
                default:
                    break
                }
                DispatchQueue.global().async {
                    // When a user-initiated transfer is successful, a Snapshot message is received over WebSocket, and
                    // a Snapshot record is inserted into the database. After the insertion is complete, the main queue
                    // is synchronously invoked from the database queue to send a NSNotification. If that process occurs
                    // simultaneously with this callback function, which synchronously accesses the database queue from
                    // the main queue, a deadlock may occur. Dispatch the database access to a background queue to
                    // avoid this issue.
                    if let trace = trace {
                        TraceDAO.shared.updateSnapshot(traceId: trace.traceId, snapshotId: snapshot.snapshotId)
                    }
                    SnapshotDAO.shared.saveSnapshots(snapshots: [snapshot])
                }
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
        case let .transfer(trackId, user, _, _):
            trace = Trace(traceId: trackId, assetId: assetId, amount: generalizedAmount, opponentId: user.userId, destination: nil, tag: nil)
            TraceDAO.shared.saveTrace(trace: trace)
            PaymentAPI.transfer(assetId: assetId, opponentId: user.userId, amount: generalizedAmount, memo: memo, pin: pin, traceId: trackId, completion: completion)
        case let .payment(payment, _):
            let transactionRequest = RawTransactionRequest(assetId: payment.assetId, opponentMultisig: OpponentMultisig(receivers: payment.receivers, threshold: payment.threshold), amount: payment.amount, pin: "", traceId: payment.traceId, memo: payment.memo)
            PaymentAPI.transactions(transactionRequest: transactionRequest, pin: pin, completion: completion)
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
            switch MultisigAction(string: multisig.action) {
            case .sign:
                MultisigAPI.sign(requestId: multisig.requestId, pin: pin, completion: multisigCompletion)
            case .revoke:
                MultisigAPI.unlock(requestId: multisig.requestId, pin: pin, completion: multisigCompletion)
            default:
                break
            }
        case let .collectible(collectible, _, _):
            let completion = { [weak self] (result: MixinAPI.Result<Empty>) in
                guard let self = self else {
                    return
                }
                switch result {
                case .success:
                    self.successHandler()
                case let .failure(error):
                    self.failedHandler(error: error)
                }
            }
            switch collectible.action {
            case CollectibleAction.sign.rawValue:
                CollectibleAPI.sign(requestId: collectible.requestId, pin: pin, completion: completion)
            case CollectibleAction.unlock.rawValue:
                CollectibleAPI.unlock(requestId: collectible.requestId, pin: pin, completion: completion)
            default:
                break
            }
        }
    }

    private func dismissWindow() {
        processing = false
        dismissPopupController(animated: true)
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
            } else if let destination {
                response = PaymentAPI.payments(assetId: asset.assetId, destination: destination, tag: tag ?? "", amount: amount, traceId: traceId)
            }

            if let result = response {
                switch result {
                case let .success(payment):
                    if payment.status == PaymentStatus.paid.rawValue {
                        DispatchQueue.main.async {
                            PayWindow.instance().render(asset: asset, action: action, amount: amount, memo: memo, error: R.string.localizable.pay_paid(), fiatMoneyAmount: fiatMoneyAmount).presentPopupControllerAnimated()
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
            case let .transfer(_, user, _, _):
                let fiatMoneyValue = amount.doubleValue * asset.priceUsd.doubleValue * Currency.current.rate
                let threshold = LoginManager.shared.account?.transferConfirmationThreshold ?? 0
                if threshold != 0 && fiatMoneyValue >= threshold {
                    DispatchQueue.main.async {
                        BigAmountConfirmationWindow.instance().render(asset: asset, user: user, amount: amount, memo: memo, completion: completion).presentPopupControllerAnimated()
                    }
                    return
                }
            default:
                break
            }

            completion(true, nil)
        }

        if AppGroupUserDefaults.User.duplicateTransferConfirmation, let trace = TraceDAO.shared.getTrace(assetId: asset.assetId, amount: amount, opponentId: opponentId, destination: destination, tag: tag, createdAt: Date().addingTimeInterval(-6 * .hour).toUTCString()) {
            let localizedAmount: String
            if fromWeb, let separator = Locale.current.decimalSeparator {
                localizedAmount = amount.replacingOccurrences(of: ".", with: separator)
            } else {
                localizedAmount = amount
            }
            if let snapshotId = trace.snapshotId, !snapshotId.isEmpty {
                DispatchQueue.main.async {
                    DuplicateConfirmationWindow.instance().render(traceCreatedAt: trace.createdAt, asset: asset, action: action, amount: localizedAmount, memo: memo, fiatMoneyAmount: fiatMoneyAmount) { (isContinue, errorMsg) in
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
                        DuplicateConfirmationWindow.instance().render(traceCreatedAt: snapshot.createdAt, asset: asset, action: action, amount: localizedAmount, memo: memo, fiatMoneyAmount: fiatMoneyAmount) { (isContinue, errorMsg) in
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
