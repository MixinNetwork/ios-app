import UIKit
import Foundation
import LocalAuthentication
import SwiftMessages
import AudioToolbox

class PayView: UIStackView {

    @IBOutlet weak var passwordPayView: UIView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var transferLoadingView: UIActivityIndicatorView!
    @IBOutlet weak var payStatusLabel: UILabel!
    @IBOutlet weak var paySuccessImageView: UIImageView!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var memoView: UIView!
    @IBOutlet weak var assetImageView: AvatarImageView!
    @IBOutlet weak var blockchainImageView: CornerImageView!

    private weak var superView: BottomSheetView?

    private let context = LAContext()
    private var user: UserItem!
    private var trackId: String!
    private var asset: AssetItem!
    private var address: Address!
    private var amount = ""
    private var memo = ""
    private(set) var processing = false
    private var soundId: SystemSoundID = 0
    private lazy var userWindow = UserWindow.instance()

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

    func render(asset: AssetItem, user: UserItem? = nil, address: Address? = nil, amount: String, memo: String, trackId: String, superView: BottomSheetView) {
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
            payStatusLabel.text = Localized.TRANSFER_PAY_PASSWORD
        } else if let address = address {
            self.address = address
            avatarImageView.isHidden = true
            nameLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.label)
            mixinIDLabel.text = address.publicKey.toSimpleKey()
            payStatusLabel.text = Localized.WALLET_WITHDRAWAL_PAY_PASSWORD
        }
        if let url = URL(string: asset.iconUrl) {
            assetImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), options: [], completed: nil)
        }
        if let chainIconUrl = asset.chainIconUrl,  let chainUrl = URL(string: chainIconUrl) {
            blockchainImageView.sd_setImage(with: chainUrl)
            blockchainImageView.isHidden = false
        } else {
            blockchainImageView.isHidden = true
        }
        memoView.isHidden = memo.isEmpty
        transferLoadingView.stopAnimating()
        transferLoadingView.isHidden = true
        pinField.isHidden = false
        pinField.clear()
        memoLabel.text = memo
        amountLabel.text =  String(format: "%@ %@", amount.formatSimpleBalance(), asset.symbol)
        amountExchangeLabel.text = String(format: "≈ %@ USD", (amount.toDouble() * asset.priceUsd.toDouble()).toFormatLegalTender())
        paySuccessImageView.isHidden = true
        dismissButton.isEnabled = true
        pinField.becomeFirstResponder()
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
        guard !processing else {
            return
        }
        processing = true
        let assetId = asset.assetId
        dismissButton.isEnabled = false

        let completion = { [weak self](result: APIResult<Snapshot>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case let .success(snapshot):
                SnapshotDAO.shared.replaceSnapshot(snapshot: snapshot)
                if weakSelf.avatarImageView.isHidden {
                    WalletUserDefault.shared.lastWithdrawalAddress[assetId] = weakSelf.address.addressId
                } else {
                    WalletUserDefault.shared.defalutTransferAssetId = assetId
                }
                WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                weakSelf.transferLoadingView.stopAnimating()
                weakSelf.transferLoadingView.isHidden = true
                weakSelf.paySuccessImageView.isHidden = false
                weakSelf.payStatusLabel.text = Localized.ACTION_DONE
                weakSelf.playSuccessSound()
                weakSelf.delayDismissWindow()
            case let .failure(error):
                weakSelf.processing = false
                weakSelf.superView?.dismissPopupControllerAnimated()
                guard error.status != NSURLErrorCancelled else {
                    return
                }
                if (weakSelf.superView as? UrlWindow)?.fromWeb ?? false {
                    SwiftMessages.showToast(message: error.localizedDescription, backgroundColor: .hintRed)
                } else {
                    UIApplication.currentActivity()?.alert(error.localizedDescription, message: nil)
                }
            }
        }

        let generalizedAmount: String
        if let decimalSeparator = Locale.current.decimalSeparator {
            generalizedAmount = amount.replacingOccurrences(of: decimalSeparator, with: ".")
        } else {
            generalizedAmount = amount
        }
        if avatarImageView.isHidden {
            WithdrawalAPI.shared.withdrawal(withdrawal: WithdrawalRequest(addressId: address.addressId, amount: generalizedAmount, traceId: trackId, pin: pin, memo: memo), completion: completion)
        } else {
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
