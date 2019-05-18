import UIKit
import Foundation
import LocalAuthentication
import AudioToolbox

class PayView: UIStackView {

    @IBOutlet weak var payView: UIStackView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var transferLoadingView: ActivityIndicatorView!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var memoView: UIView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var paySuccessImageView: UIImageView!
    @IBOutlet weak var biometricButton: UIButton!
    @IBOutlet weak var biometricPlaceView: UIView!

    private weak var superView: BottomSheetView?

    private lazy var context = LAContext()
    private var user: UserItem!
    private var trackId: String!
    private var asset: AssetItem!
    private var address: Address?
    private var addressRequest: AddressRequest?
    private var amount = ""
    private var memo = ""
    private var isWithdrawal = false
    private var fromWebWithdrawal = false
    private(set) var processing = false
    private var soundId: SystemSoundID = 0
    private var isAutoFillPIN = false
    private var isAllowBiometricPay: Bool {
        guard #available(iOS 11.0, *) else {
            return false
        }

        guard WalletUserDefault.shared.isBiometricPay else {
            return false
        }
        guard Date().timeIntervalSince1970 - WalletUserDefault.shared.lastInputPinTime < WalletUserDefault.shared.pinInterval else {
            return false
        }
        guard !isWithdrawal else {
            return false
        }

        guard biometryType != .none else {
            return false
        }

        return true
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

    deinit {
        if soundId != 0 {
            AudioServicesRemoveSystemSoundCompletion(soundId)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    func render(asset: AssetItem, user: UserItem? = nil, address: Address? = nil, addressRequest: AddressRequest? = nil, amount: String, memo: String, trackId: String, fromWebWithdrawal: Bool = false, amountUsd: String? = nil, superView: BottomSheetView) {
        self.asset = asset
        self.amount = amount
        self.memo = memo
        self.trackId = trackId
        self.superView = superView
        self.fromWebWithdrawal = fromWebWithdrawal
        if let user = user {
            self.isWithdrawal = false
            self.user = user
            avatarImageView.setImage(with: user)
            nameLabel.text = Localized.PAY_TRANSFER_TITLE(fullname: user.fullName)
            mixinIDLabel.text = user.identityNumber
        } else if let address = address {
            self.isWithdrawal = true
            self.address = address
            avatarImageView.image = R.image.wallet.ic_transaction_external()
            if asset.isAccount {
                nameLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.accountName ?? "")
                mixinIDLabel.text = address.accountTag?.toSimpleKey()
            } else {
                nameLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.label ?? "")
                mixinIDLabel.text = address.publicKey?.toSimpleKey()
            }
        } else if let address = addressRequest {
            self.isWithdrawal = true
            self.addressRequest = address
            avatarImageView.image = R.image.wallet.ic_transaction_external()
            if asset.isAccount {
                nameLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.accountName ?? "")
                mixinIDLabel.text = address.accountTag?.toSimpleKey()
            } else {
                nameLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.label ?? "")
                mixinIDLabel.text = address.publicKey?.toSimpleKey()
            }
        }
        preparePayView(show: true)
        assetIconView.setIcon(asset: asset)
        pinField.clear()
        memoLabel.isHidden = memo.isEmpty
        memoLabel.text = memo

        let amountToken = CurrencyFormatter.localizedString(from: amount, locale: .current, format: .pretty, sign: .whenNegative, symbol: .custom(asset.symbol))
        if let amountUsd = amountUsd {
            amountLabel.text = amountUsd
            amountExchangeLabel.text = amountToken
        } else {
            amountLabel.text = amountToken
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: amount.doubleValue * asset.priceUsd.doubleValue, format: .legalTender, sign: .never, symbol: .usd)
        }

        dismissButton.isEnabled = true
        pinField.becomeFirstResponder()
    }

    private func preparePayView(show: Bool) {
        payView.isHidden = !show
        statusView.isHidden = show
        if show {
            payView.isHidden = false
            statusView.isHidden = true
            transferLoadingView.stopAnimating()
            let biometricPay = self.isAllowBiometricPay
            if biometricPay {
                if biometryType == .faceID {
                    biometricButton.setTitle(Localized.PAY_USE_FACE, for: .normal)
                    biometricButton.setImage(R.image.ic_pay_face(), for: .normal)
                } else {
                    biometricButton.setTitle(Localized.PAY_USE_TOUCH, for: .normal)
                    biometricButton.setImage(R.image.ic_pay_touch(), for: .normal)
                }
            }
            biometricButton.isHidden = !biometricPay
            biometricPlaceView.isHidden = !biometricPay
        } else {
            UIView.animate(withDuration: 0.15) {
                self.payView.isHidden = true
                self.statusView.isHidden = false
            }
            transferLoadingView.startAnimating()
        }
        paySuccessImageView.isHidden = true
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
                self?.pinField.insertText(pin)
            }
        }

    }

    @IBAction func dismissAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    class func instance() -> PayView {
        return Bundle.main.loadNibNamed("PayView", owner: nil, options: nil)?.first as! PayView
    }
}

extension PayView {

    @objc func keyboardWillAppear(_ sender: Notification) {
        guard let info = sender.userInfo, let superView = self.superView, superView.isShowing else {
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
            superView.contentBottomConstraint.constant = endKeyboardRect.height
            (superView as? UrlWindow)?.contentHeightConstraint.constant = 318
            superView.layoutIfNeeded()
            self.layoutIfNeeded()
        }, completion: nil)
    }

    @objc func keyboardWillDisappear(_ sender: Notification) {
        guard let info = sender.userInfo, let superView = self.superView, superView.isShowing else {
            return
        }
        guard let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
            return
        }
        guard let animation = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue else {
            return
        }
        let options = UIView.AnimationOptions(rawValue: UInt(animation << 16))

        if paySuccessImageView.isHidden {
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                superView.alpha = 0
                superView.popupView.center = superView.getAnimationStartPoint()
            }, completion: { (_) in
                superView.isShowing = false
                superView.removeFromSuperview()
            })
        } else {
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                superView.contentBottomConstraint.constant = 0
                superView.layoutIfNeeded()
            }, completion: nil)
        }
    }

}

extension PayView: PinFieldDelegate {

    func inputFinished(pin: String) {
        transferAction(pin: pin)
    }

    private func failedHandler(error: APIError) {
        processing = false
        superView?.dismissPopupControllerAnimated()
        guard error.status != NSURLErrorCancelled else {
            return
        }
        if (superView as? UrlWindow)?.fromWeb ?? false {
            showHud(style: .error, text: error.localizedDescription)
        } else {
            UIApplication.currentActivity()?.alert(error.localizedDescription, message: nil)
        }
    }

    private func failedHandler(errorMsg: String) {
        processing = false
        superView?.dismissPopupControllerAnimated()

        if (superView as? UrlWindow)?.fromWeb ?? false {
            showHud(style: .error, text: errorMsg)
        } else {
            UIApplication.currentActivity()?.alert(errorMsg, message: nil)
        }
    }

    private func transferAction(pin: String) {
        guard !processing else {
            return
        }
        processing = true
        let assetId = asset.assetId
        dismissButton.isEnabled = false
        preparePayView(show: false)

        let completion = { [weak self](result: APIResult<Snapshot>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case let .success(snapshot):
                if weakSelf.isWithdrawal {
                    if let address = weakSelf.address {
                        WalletUserDefault.shared.lastWithdrawalAddress[assetId] = address.addressId
                        if weakSelf.addressRequest != nil {
                            AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                            weakSelf.tipAddAddress(asset: weakSelf.asset, address: address)
                        }
                    }
                    ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: snapshot.assetId))
                } else {
                    WalletUserDefault.shared.defalutTransferAssetId = assetId
                }
                SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: [snapshot])
                if !weakSelf.isAutoFillPIN {
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                }
                weakSelf.transferLoadingView.stopAnimating()
                weakSelf.paySuccessImageView.isHidden = false
                weakSelf.playSuccessSound()
                weakSelf.delayDismissWindow()
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
        if isWithdrawal {
            if fromWebWithdrawal {
                checkAddressAndPayments(pin: pin, trackId: trackId, amount: generalizedAmount) { [weak self](address) in
                    guard let weakSelf = self else {
                        return
                    }
                     WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: weakSelf.trackId, pin: pin, memo: weakSelf.memo), completion: completion)
                }
            } else if let address = self.address {
                WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo), completion: completion)
            }
        } else {
            CommonUserDefault.shared.hasPerformedTransfer = true
            AssetAPI.shared.transfer(assetId: assetId, opponentId: user.userId, amount: generalizedAmount, memo: memo, pin: pin, traceId: trackId, completion: completion)
        }
    }

    private func checkAddressAndPayments(pin: String, trackId: String, amount: String, block: @escaping (Address) -> Void) {
        let assetId = asset.assetId
        let checkPayments = { [weak self](address: Address) in
            AssetAPI.shared.payments(assetId: assetId, addressId: address.addressId, amount: amount, traceId: trackId) { (result) in
                guard let weakSelf = self else {
                    return
                }
                switch result {
                case let .success(payment):
                    guard payment.status != PaymentStatus.paid.rawValue else {
                        weakSelf.failedHandler(errorMsg: Localized.TRANSFER_PAID)
                        return
                    }
                    block(address)
                case let .failure(error):
                    weakSelf.failedHandler(error: error)
                }
            }
        }

        if let address = self.address {
            checkPayments(address)
        } else {
            self.addressRequest?.pin = pin
            if let addressRequest = self.addressRequest {
                WithdrawalAPI.shared.save(address: addressRequest) { [weak self](result) in
                    guard let weakSelf = self else {
                        return
                    }

                    switch result {
                    case let .success(address):
                        weakSelf.address = address
                        checkPayments(address)
                    case let .failure(error):
                        weakSelf.failedHandler(error: error)
                    }
                }
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
            weakSelf.superView?.dismissPopupControllerAnimated()
            
            guard !((weakSelf.superView as? UrlWindow)?.fromWeb ?? false) else {
                return
            }
            guard !weakSelf.fromWebWithdrawal else {
                return
            }
            guard let navigation = UIApplication.rootNavigationController() else {
                return
            }
            var viewControllers = navigation.viewControllers
            if weakSelf.isWithdrawal {
                while (viewControllers.count > 0 && !(viewControllers.last is HomeViewController)) {
                    if let _ = (viewControllers.last as? ContainerViewController)?.viewController as? AssetViewController {
                        break
                    }
                    viewControllers.removeLast()
                }
            } else if let ownerUser = weakSelf.user {
                if (viewControllers.first(where: { $0 is ConversationViewController }) as? ConversationViewController)?.dataSource.ownerUser?.userId == ownerUser.userId {
                    while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
                        viewControllers.removeLast()
                    }
                } else {
                    while (viewControllers.count > 0 && !(viewControllers.last is HomeViewController)) {
                        viewControllers.removeLast()
                    }
                    viewControllers.append(ConversationViewController.instance(ownerUser: ownerUser))
                }
            }
            navigation.setViewControllers(viewControllers, animated: true)
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

    private func tipAddAddress(asset: AssetItem, address: Address) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if asset.isAccount {
                UIApplication.currentActivity()?.alert(Localized.ADDRESS_AUTO_ADD_ACCOUNT(accountName: address.accountName ?? "", accountTag: address.accountTag ?? "", symbol: asset.symbol), actionTitle: R.string.localizable.dialog_button_got_it())
            } else {
                UIApplication.currentActivity()?.alert(Localized.ADDRESS_AUTO_ADD(label: address.label ?? "", publicKey: address.publicKey ?? "", symbol: asset.symbol), actionTitle: R.string.localizable.dialog_button_got_it())
            }
        }
    }
}
