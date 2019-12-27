import UIKit
import Foundation

class AddressView: UIStackView {

    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var pinTipLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton!

    enum action {
        case add
        case update
        case delete
    }

    private weak var superView: BottomSheetView?
    private var addressAction = action.add
    private var addressRequest: AddressRequest?
    private var address: Address?
    private var fromWeb = false
    
    private(set) var processing = false
    private(set) var dismissCallback: ((Bool) -> Void)?

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
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func dismissAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    func render(action: action, asset: AssetItem, addressRequest: AddressRequest?, address: Address?, dismissCallback: ((Bool) -> Void)?, superView: BottomSheetView) {
        self.addressAction = action
        self.address = address
        self.addressRequest = addressRequest
        self.dismissCallback = dismissCallback
        self.superView = superView

        switch addressAction {
        case .add:
            titleLabel.text = Localized.ADDRESS_NEW_TITLE(symbol: asset.symbol)
        case .update:
            titleLabel.text = Localized.ADDRESS_EDIT_TITLE(symbol: asset.symbol)
        case .delete:
            titleLabel.text = Localized.ADDRESS_DELETE_TITLE(symbol: asset.symbol)
        }
        if let address = addressRequest {
            nameLabel.text = address.label
            addressLabel.text = address.fullAddress
        } else if let address = address {
            nameLabel.text = address.label
            addressLabel.text = address.fullAddress
        }
        assetIconView.setIcon(asset: asset)
        pinField.clear()

        dismissButton.isEnabled = true
        pinField.becomeFirstResponder()
    }

    class func instance() -> AddressView {
        return Bundle.main.loadNibNamed("AddressView", owner: nil, options: nil)?.first as! AddressView
    }
}

extension AddressView: PinFieldDelegate {

    func inputFinished(pin: String) {
        saveAddressAction(pin: pin)
    }

    private func saveAddressAction(pin: String) {
        dismissButton.isEnabled = false
        UIView.animate(withDuration: 0.15) {
            self.pinField.isHidden = true
            self.pinTipLabel.isHidden = true
            self.loadingView.isHidden = false
        }
        loadingView.startAnimating()

        if addressAction == .delete {
            guard let addressId = self.address?.addressId, let assetId = self.address?.assetId else {
                return
            }
            WithdrawalAPI.shared.delete(addressId: addressId, pin: pin) { [weak self](result) in
                self?.processing = false
                switch result {
                case .success:
                    self?.pinField.resignFirstResponder()
                    AddressDAO.shared.deleteAddress(assetId: assetId, addressId: addressId)
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.toast_deleted())
                case let .failure(error):
                    if error.code == 429 {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.wallet_password_too_many_requests())
                    } else {
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                    self?.superView?.dismissPopupControllerAnimated()
                }
            }
        } else {
            addressRequest?.pin = pin
            guard let address = addressRequest else {
                return
            }
            WithdrawalAPI.shared.save(address: address) { [weak self](result) in
                self?.processing = false
                switch result {
                case let .success(address):
                    self?.pinField.resignFirstResponder()
                    AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                    showAutoHiddenHud(style: .notification, text: Localized.TOAST_SAVED)
                case let .failure(error):
                    if error.code == 429 {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.wallet_password_too_many_requests())
                    } else {
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                    self?.superView?.dismissPopupControllerAnimated()
                }
            }
        }
    }
}

extension AddressView {

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

        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            UIView.setAnimationCurve(.overdamped)
            superView.contentBottomConstraint.constant = 0
            superView.alpha = 0
            superView.layoutIfNeeded()
        }, completion: { (_) in
            superView.isShowing = false
            superView.removeFromSuperview()
            self.dismissCallback?(true)
        })
    }

}
