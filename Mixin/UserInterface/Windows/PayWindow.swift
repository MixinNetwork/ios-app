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
        case withdraw(trackId: String, address: Address, feeAsset: AssetItem, fromWeb: Bool)
        case multisig(multisig: MultisigResponse, senders: [UserItem], receivers: [UserItem])
        case collectible(collectible: CollectibleResponse, senders: [UserItem], receivers: [UserItem])
        case externalTransfer(trackId: String, addressId: String, destination: String, fee: String, feeAsset: AssetItem, tag: String?)
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
    @IBOutlet weak var assetIconView: AssetIconView!
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
    private var withdrawlFee: String?
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
            resultViewPlaceHeightConstraint.constant = 30
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
            case let .transfer(_, user, _):
                multisigView.isHidden = true
                nameLabel.text = R.string.localizable.transfer_to(user.fullName)
                mixinIDLabel.text = user.isCreatedByMessenger ? user.identityNumber : user.userId
                mixinIDLabel.textColor = .accessoryText
                pinView.isHidden = false
            case let .withdraw(_, address, feeAsset, _):
                multisigView.isHidden = true
                nameLabel.text = R.string.localizable.withdrawal_to(address.label)
                mixinIDLabel.text = address.fullAddress
                withdrawlFee = updateAmountExchangeForWithdraw(fee: address.fee, feeAsset: feeAsset)
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
                switch multisig.action {
                case MultisigAction.sign.rawValue:
                    multisigActionView.image = R.image.multisig_sign()
                    nameLabel.text = R.string.localizable.multisig_transaction()
                case MultisigAction.unlock.rawValue:
                    multisigActionView.image = R.image.multisig_revoke()
                    nameLabel.text = R.string.localizable.revoke_multisig_transaction()
                default:
                    break
                }
                mixinIDLabel.text = multisig.memo
                renderMultisigInfo(senders: senders, receivers: receivers)
            case let .externalTransfer(_, _, destination, fee, feeAsset, _):
                multisigView.isHidden = true
                nameLabel.text = R.string.localizable.withdrawal()
                mixinIDLabel.text = destination
                withdrawlFee = updateAmountExchangeForWithdraw(fee: fee, feeAsset: feeAsset)
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
            resultViewPlaceHeightConstraint.constant = 10
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
            errorContinueAction = .close
            pinView.isHidden = true
            biometricButton.isHidden = true
            successView.isHidden = true
            errorView.isHidden = false
            errorLabel.text = error
        } else {
            resetPinInput()
            if isAllowBiometricPay {
                biometricButton.setTitle(R.string.localizable.use_biometry(biometryType.localizedName), for: .normal)
            } else {
                pinViewHeightConstraint.constant = 36
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

        let prompt = R.string.localizable.authorize_payment_via(biometryType.localizedName)
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
        isDelayDismissCancelled = true
        processing = false
        dismissPopupController(animated: true)
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
            var message = description
            switch error {
            case .malformedPin, .incorrectPin, .insufficientPool, .internalServerError:
                self.errorContinueAction = .retryPin
                self.failedHandler(errorMsg: message)
            case .insufficientFee:
                if let fee = self.withdrawlFee {
                    message = R.string.localizable.error_insufficient_transaction_fee_with_amount(fee)
                }
                self.errorContinueAction = .close
                self.failedHandler(errorMsg: message)
            case .withdrawFeeTooSmall:
                if let oldFee = self.withdrawlFee, case let .withdraw(trackId, address, feeAsset, fromWeb) = self.pinAction {
                    WithdrawalAPI.address(addressId: address.addressId) { result in
                        if case let .success(address) = result {
                            AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                            let newFee = self.updateAmountExchangeForWithdraw(fee: address.fee, feeAsset: feeAsset)
                            message = R.string.localizable.wallet_withdrawal_changed(oldFee, newFee)
                            self.pinAction = .withdraw(trackId: trackId, address: address, feeAsset: feeAsset, fromWeb: fromWeb)
                            self.withdrawlFee = newFee
                            self.errorContinueAction = .retryPin
                            self.failedHandler(errorMsg: message)
                        } else {
                            self.errorContinueAction = .close
                            self.failedHandler(errorMsg: message)
                        }
                    }
                } else {
                    self.errorContinueAction = .close
                    self.failedHandler(errorMsg: message)
                }
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
                if let trace = trace {
                    TraceDAO.shared.updateSnapshot(traceId: trace.traceId, snapshotId: snapshot.snapshotId)
                }
                switch pinAction {
                case .transfer, .payment:
                    AppGroupUserDefaults.User.hasPerformedTransfer = true
                    AppGroupUserDefaults.Wallet.defaultTransferAssetId = assetId
                case let .withdraw(_,address,_,_):
                    AppGroupUserDefaults.Wallet.withdrawnAddressIds[address.addressId] = true
                    let job = RefreshAssetsJob(request: .asset(id: snapshot.assetId, untilDepositEntriesNotEmpty: false))
                    ConcurrentJobQueue.shared.addJob(job: job)
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
            let request = WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo, fee: address.fee, assetId: nil, destination: nil, tag: nil)
            WithdrawalAPI.withdrawal(withdrawal: request, completion: completion)
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
        case let .externalTransfer(trackId, addressId, destination, fee, _, tag):
            trace = Trace(traceId: trackId, assetId: assetId, amount: generalizedAmount, opponentId: nil, destination: destination, tag: tag)
            TraceDAO.shared.saveTrace(trace: trace)
            let request = WithdrawalRequest(addressId: "", amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo, fee: fee, assetId: assetId, destination: destination, tag: tag)
            WithdrawalAPI.externalWithdrawal(addressId: addressId, withdrawal: request, completion: completion)
        }
    }

    private func delayDismissWindow(delay: TimeInterval = 2) {
        pinField.resignFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let weakSelf = self, !weakSelf.isDelayDismissCancelled else {
                return
            }
            weakSelf.processing = false
            weakSelf.dismissPopupController(animated: true)

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
            case .collectible:
                break
            case .externalTransfer:
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
            case let .transfer(_, user, _):
                let fiatMoneyValue = amount.doubleValue * asset.priceUsd.doubleValue * Currency.current.rate
                let threshold = LoginManager.shared.account?.transferConfirmationThreshold ?? 0
                if threshold != 0 && fiatMoneyValue >= threshold {
                    DispatchQueue.main.async {
                        BigAmountConfirmationWindow.instance().render(asset: asset, user: user, amount: amount, memo: memo, completion: completion).presentPopupControllerAnimated()
                    }
                    return
                }
            case let .withdraw(_, address, _, _):
                let decimalAmount: Decimal?
                if let decimalSeparator = Locale.current.decimalSeparator, decimalSeparator != ".", amount.contains(decimalSeparator) {
                    decimalAmount = Decimal(string: amount, locale: .current)
                } else {
                    decimalAmount = Decimal(string: amount, locale: .us)
                }
                if let amount = decimalAmount, let dust = Decimal(string: address.dust, locale: .us), amount < dust {
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
