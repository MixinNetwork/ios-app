import UIKit
import Foundation
import LocalAuthentication
import SwiftMessages
import AudioToolbox

class PayView: UIStackView {

    @IBOutlet weak var fingerPayView: UIView!
    @IBOutlet weak var passwordPayView: UIView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var payButton: StateResponsiveButton!
    @IBOutlet weak var transferAssetLabel: UILabel!
    @IBOutlet weak var transferLoadingView: UIActivityIndicatorView!
    @IBOutlet weak var payStatusLabel: UILabel!
    @IBOutlet weak var paySuccessImageView: UIImageView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var addressView: UIView!
    @IBOutlet weak var userView: UIView!
    

    private weak var superView: BottomSheetView?

    private let context = LAContext()
    private var user: UserItem!
    private var trackId: String!
    private var asset: Asset!
    private var address: Address!
    private var amount = ""
    private var memo = ""
    private(set) var transfering = false
    private var soundId: SystemSoundID = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        pinField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    deinit {
        if soundId != 0 {
            AudioServicesRemoveSystemSoundCompletion(soundId)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func render(asset: Asset, user: UserItem? = nil, address: Address? = nil, amount: String, memo: String, trackId: String, superView: BottomSheetView) {
        self.asset = asset
        self.amount = amount
        self.memo = memo
        self.trackId = trackId
        self.superView = superView
        if let user = user {
            self.user = user
            userView.isHidden = false
            addressView.isHidden = true
            avatarImageView.setImage(with: user)
            nameLabel.text = user.fullName
            mixinIDLabel.text = Localized.PROFILE_MIXIN_ID(id: user.identityNumber)
            transferAssetLabel.text = Localized.TRANSFER_ASSET(assetName: asset.name)
            payStatusLabel.text = Localized.TRANSFER_PAY_PASSWORD
        } else if let address = address {
            self.address = address
            userView.isHidden = true
            addressView.isHidden = false
            addressLabel.text = "\(address.label) (\(address.publicKey))"
            transferAssetLabel.text = Localized.WALLET_WITHDRAWAL_ASSET(assetName: asset.name)
            payStatusLabel.text = Localized.WALLET_WITHDRAWAL_PAY_PASSWORD
        }
        transferLoadingView.stopAnimating()
        transferLoadingView.isHidden = true
        pinField.isHidden = false
        pinField.clear()
        memoLabel.text = memo
        amountLabel.text =  String(format: "%@ %@", amount, asset.symbol)
        amountExchangeLabel.text = String(format: "≈ %@ USD", (amount.toDouble() * asset.priceUsd.toDouble()).toFormatLegalTender())
        paySuccessImageView.isHidden = true
        pinField.becomeFirstResponder()
    }

    @IBAction func cancelAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    @IBAction func payAction(_ sender: Any) {
        guard !payButton.isBusy else {
            return
        }
        payButton.isBusy = true
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: Localized.TRANSFER_TOUCH_ID_REASON) { [weak self](success, error) in
            guard let weakSelf = self else {
                return
            }
            DispatchQueue.main.async {
                if success {
                    //weakSelf.transferAction()
                } else {
                    if error?.errorCode == LAError.userCancel.rawValue {

                    } else {
                        weakSelf.passwordPayView.isHidden = false
                        weakSelf.fingerPayView.isHidden = true
                        weakSelf.pinField.becomeFirstResponder()
                    }
                    weakSelf.payButton.isBusy = false
                }
            }
        }
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
        guard let duration = (info[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
            return
        }
        guard let endKeyboardRect = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        guard let animation = (info[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue else {
            return
        }
        let options = UIViewAnimationOptions(rawValue: UInt(animation << 16))
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
        guard let duration = (info[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
            return
        }
        guard let animation = (info[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue else {
            return
        }
        let options = UIViewAnimationOptions(rawValue: UInt(animation << 16))

        if paySuccessImageView.isHidden {
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                superView.alpha = 0
                superView.popupView.center = superView.getAnimationStartPoint()
            }, completion: { (_) in
                superView.isShowing = false
                NotificationCenter.default.postOnMain(name: .WindowDidDisappear)
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
        transferLoadingView.startAnimating()
        transferLoadingView.isHidden = false
        pinField.isHidden = true
        transferAction(pin: pin)
    }

    private func transferAction(pin: String) {
        guard !transfering else {
            return
        }
        transfering = true
        cancelButton.isHidden = true
        let assetId = asset.assetId

        let completion = { [weak self](result: APIResult<Snapshot>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case let .success(snapshot):
                SnapshotDAO.shared.replaceSnapshot(snapshot: snapshot)
                if weakSelf.addressView.isHidden {
                    WalletUserDefault.shared.defalutTransferAssetId = assetId
                } else {
                    WalletUserDefault.shared.lastWithdrawalAddress[assetId] = weakSelf.address.addressId
                }
                WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                weakSelf.transferLoadingView.stopAnimating()
                weakSelf.transferLoadingView.isHidden = true
                weakSelf.payButton.isBusy = false
                weakSelf.paySuccessImageView.isHidden = false
                weakSelf.payStatusLabel.text = Localized.ACTION_DONE
                weakSelf.playSuccessSound()
                weakSelf.delayDismissWindow()
            case let .failure(error, _):
                weakSelf.transfering = false
                weakSelf.superView?.dismissPopupControllerAnimated()
                guard error.kind != .cancelled else {
                    return
                }
                let errorMsg = error.kind.localizedDescription ?? error.description
                if (weakSelf.superView as? UrlWindow)?.fromWeb ?? false {
                    SwiftMessages.showToast(message: errorMsg, backgroundColor: .hintRed)
                } else {
                    UIApplication.currentActivity()?.alert(errorMsg, message: nil)
                }
            }
        }

        if addressView.isHidden {
            AssetAPI.shared.transfer(assetId: assetId, counterUserId: user.userId, amount: amount, memo: memo, pin: pin, traceId: trackId, completion: completion)
        } else {
            WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: amount, traceId: trackId, pin: pin, memo: memo), completion: completion)
        }
    }

    private func delayDismissWindow() {
        pinField.resignFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.transfering = false
            weakSelf.superView?.dismissPopupControllerAnimated()
            if let lastViewController = UIApplication.rootNavigationController()?.viewControllers.last, lastViewController is TransferViewController || lastViewController is WithdrawalViewController || lastViewController is CameraViewController {
                UIApplication.rootNavigationController()?.popViewController(animated: true)
            }
        }
    }

    func playSuccessSound() {
        if soundId == 0 {
            guard let path = Bundle.main.path(forResource: "payment_success", ofType: "caf") else {
                return
            }
            AudioServicesCreateSystemSoundID(URL(fileURLWithPath: path) as CFURL, &soundId)
        }
        AudioServicesPlaySystemSound(soundId)
    }
}
