import UIKit
import Foundation
import LocalAuthentication
import AudioToolbox

class PayView: UIStackView {

    @IBOutlet weak var payView: UIView!
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

    private weak var superView: BottomSheetView?

    private lazy var context = LAContext()
    private var user: UserItem!
    private var trackId: String!
    private var asset: AssetItem!
    private var address: Address!
    private var amount = ""
    private var memo = ""
    private(set) var processing = false
    private var soundId: SystemSoundID = 0
    private var isAutoFillPIN = false
    private var biometricPayTimedOut: Bool {
        return Date().timeIntervalSince1970 - WalletUserDefault.shared.lastInputPinTime >= WalletUserDefault.shared.pinInterval
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
    
    func render(asset: AssetItem, user: UserItem? = nil, address: Address? = nil, amount: String, memo: String, trackId: String, amountUsd: String? = nil, superView: BottomSheetView) {
        self.asset = asset
        self.amount = amount
        self.memo = memo
        self.trackId = trackId
        self.superView = superView
        if let user = user {
            self.user = user
            avatarImageView.setImage(with: user)
            avatarImageView.isHidden = false
            nameLabel.text = Localized.PAY_TRANSFER_TITLE(fullname: user.fullName)
            mixinIDLabel.text = user.identityNumber
        } else if let address = address {
            self.address = address
            avatarImageView.isHidden = true
            if asset.isAccount {
                nameLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.accountName ?? "")
                mixinIDLabel.text = address.accountTag
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


        if !biometricsPayAction() {
            DispatchQueue.main.async(execute: alertScreenCapturedIfNeeded)
        }
    }

    private func preparePayView(show: Bool) {
        payView.isHidden = !show
        statusView.isHidden = show
        if show {
            payView.isHidden = false
            statusView.isHidden = true
            transferLoadingView.stopAnimating()
        } else {
            UIView.animate(withDuration: 0.15) {
                self.payView.isHidden = true
                self.statusView.isHidden = false
            }
            transferLoadingView.startAnimating()
        }
        paySuccessImageView.isHidden = true
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

    private func transferAction(pin: String) {
        guard !processing else {
            return
        }
        processing = true
        let assetId = asset.assetId
        let isWithdrawal = avatarImageView.isHidden
        dismissButton.isEnabled = false
        preparePayView(show: false)

        let completion = { [weak self](result: APIResult<Snapshot>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case let .success(snapshot):
                if isWithdrawal {
                    ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: snapshot.assetId))
                }
                SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: [snapshot])
                if weakSelf.avatarImageView.isHidden {
                    WalletUserDefault.shared.lastWithdrawalAddress[assetId] = weakSelf.address.addressId
                } else {
                    WalletUserDefault.shared.defalutTransferAssetId = assetId
                }
                if !weakSelf.isAutoFillPIN {
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                }
                weakSelf.transferLoadingView.stopAnimating()
                weakSelf.paySuccessImageView.isHidden = false
                weakSelf.playSuccessSound()
                weakSelf.delayDismissWindow()
            case let .failure(error):
                weakSelf.processing = false
                weakSelf.superView?.dismissPopupControllerAnimated()
                guard error.status != NSURLErrorCancelled else {
                    return
                }
                if (weakSelf.superView as? UrlWindow)?.fromWeb ?? false {
                    showHud(style: .error, text: error.localizedDescription)
                } else {
                    UIApplication.currentActivity()?.alert(error.localizedDescription, message: nil)
                }
            }
        }

        let generalizedAmount: String
        if let decimalSeparator = Locale.current.decimalSeparator, decimalSeparator != "." {
            generalizedAmount = amount.replacingOccurrences(of: decimalSeparator, with: ".")
        } else {
            generalizedAmount = amount
        }
        if isWithdrawal {
            WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo), completion: completion)
        } else {
            CommonUserDefault.shared.hasPerformedTransfer = true
            AssetAPI.shared.transfer(assetId: assetId, opponentId: user.userId, amount: generalizedAmount, memo: memo, pin: pin, traceId: trackId, completion: completion)
        }
    }

    private func biometricsPayAction() -> Bool {
        guard #available(iOS 11.0, *) else {
            return false
        }

        guard WalletUserDefault.shared.isBiometricPay else {
            return false
        }
        guard !biometricPayTimedOut else {
            return false
        }
        
        guard biometryType != .none else {
            return false
        }

        let prompt = Localized.WALLET_BIOMETRIC_PAY_PROMPT(biometricType: biometryType.localizedName)

        DispatchQueue.global().async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            guard let pin = Keychain.shared.getPIN(prompt: prompt) else {
                DispatchQueue.main.async(execute: weakSelf.alertScreenCapturedIfNeeded)
                return
            }
            DispatchQueue.main.async {
                self?.isAutoFillPIN = true
                self?.pinField.insertText(pin)
            }
        }

        return true
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
            guard let navigation = UIApplication.rootNavigationController(), let ownerUser = weakSelf.user else {
                return
            }
            var viewControllers = navigation.viewControllers

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
    
    private func alertScreenCapturedIfNeeded() {
        guard window != nil, #available(iOS 11.0, *), UIScreen.main.isCaptured else {
            return
        }
        var prompt = Localized.SCREEN_CAPTURED_PIN_LEAKING_HINT
        if biometryType != .none {
            prompt += Localized.BIOMETRY_SUGGESTION(biometricType: biometryType.localizedName)
        }
        UIApplication.currentActivity()?.alert(prompt)
    }
    
}
