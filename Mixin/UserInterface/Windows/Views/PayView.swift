import UIKit
import Foundation
import LocalAuthentication
import AudioToolbox

class PayView: UIStackView {

    @IBOutlet weak var payView: UIStackView!
    @IBOutlet weak var pinField: PinField!
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
    private var amount = ""
    private var memo = ""
    private var isWithdrawal = false
    private var fromWebWithdrawal = false
    private(set) var processing = false
    private var soundId: SystemSoundID = 0
    private var isAutoFillPIN = false
    private var isAllowBiometricPay: Bool {
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
    
    func render(asset: AssetItem, user: UserItem? = nil, address: Address? = nil, amount: String, memo: String, trackId: String, fromWebWithdrawal: Bool = false, fiatMoneyAmount: String? = nil, superView: BottomSheetView) {
        self.asset = asset
        self.amount = amount
        self.memo = memo
        self.trackId = trackId
        self.superView = superView
        self.fromWebWithdrawal = fromWebWithdrawal
        if let user = user {
            self.isWithdrawal = false
            self.user = user
            nameLabel.text = Localized.PAY_TRANSFER_TITLE(fullname: user.fullName)
            mixinIDLabel.text = user.identityNumber
        } else if let address = address {
            self.isWithdrawal = true
            self.address = address
            nameLabel.text = R.string.localizable.pay_withdrawal_title(address.label)
            mixinIDLabel.text = address.fullAddress
        }
        preparePayView(show: true)
        assetIconView.setIcon(asset: asset)
        pinField.clear()
        memoLabel.isHidden = memo.isEmpty
        memoLabel.text = memo

        let amountToken = CurrencyFormatter.localizedString(from: amount, locale: .current, format: .precision, sign: .whenNegative, symbol: .custom(asset.symbol))
        if let fiatMoneyAmount = fiatMoneyAmount {
            amountLabel.text = fiatMoneyAmount
            amountExchangeLabel.text = amountToken
        } else {
            amountLabel.text = amountToken
            let value = amount.doubleValue * asset.priceUsd.doubleValue * Currency.current.rate
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: value, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
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
        UIApplication.traceError(error)

        let errorMsg = error.code == 429 ? R.string.localizable.wallet_password_too_many_requests() : error.localizedDescription
        if (superView as? UrlWindow)?.fromWeb ?? false {
            showAutoHiddenHud(style: .error, text: errorMsg)
        } else {
            UIApplication.currentActivity()?.alert(errorMsg, message: nil)
        }
    }

    private func failedHandler(errorMsg: String) {
        processing = false
        superView?.dismissPopupControllerAnimated()

        if (superView as? UrlWindow)?.fromWeb ?? false {
            showAutoHiddenHud(style: .error, text: errorMsg)
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
                        WalletUserDefault.shared.depositWithdrawalTip.removeAll( where: { $0 == address.addressId })
                        WalletUserDefault.shared.depositWithdrawalTip.append(address.addressId)
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
            guard let address = self.address else {
                return
            }
            if fromWebWithdrawal {
                AssetAPI.shared.payments(assetId: asset.assetId, addressId: address.addressId, amount: amount, traceId: trackId) { [weak self](result) in
                    guard let weakSelf = self else {
                        return
                    }
                    switch result {
                    case let .success(payment):
                        guard payment.status != PaymentStatus.paid.rawValue else {
                            weakSelf.failedHandler(errorMsg: Localized.TRANSFER_PAID)
                            return
                        }
                        WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: weakSelf.trackId, pin: pin, memo: weakSelf.memo), completion: completion)
                    case let .failure(error):
                        weakSelf.failedHandler(error: error)
                    }
                }
            } else {
                WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo), completion: completion)
            }
        } else {
            CommonUserDefault.shared.hasPerformedTransfer = true
            AssetAPI.shared.transfer(assetId: assetId, opponentId: user.userId, amount: generalizedAmount, memo: memo, pin: pin, traceId: trackId, completion: completion)
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
            guard let navigation = UIApplication.homeNavigationController else {
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
}
