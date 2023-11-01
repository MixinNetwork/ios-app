import UIKit
import MixinServices

class LegacyAddressView: UIStackView {

    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var subtitlePlaceView: UIView!
    @IBOutlet weak var dismissButton: UIButton!
    
    @IBOutlet weak var passwordViewHeightConstraint: NSLayoutConstraint!
    
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
    private var asset: AssetItem!
    
    private(set) var processing = false
    
    var dismissCallback: ((Bool) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        pinField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func dismissAction(_ sender: Any) {
        superView?.dismissPopupController(animated: true)
    }

    func render(action: action, asset: AssetItem, addressRequest: AddressRequest?, address: Address?, dismissCallback: ((Bool) -> Void)?, superView: BottomSheetView) {
        self.addressAction = action
        self.address = address
        self.addressRequest = addressRequest
        self.dismissCallback = dismissCallback
        self.superView = superView
        self.asset = asset

        switch addressAction {
        case .add:
            titleLabel.text = R.string.localizable.withdrawal_addr_new(asset.symbol)
        case .update:
            titleLabel.text = R.string.localizable.edit_address(asset.symbol)
        case .delete:
            titleLabel.text = R.string.localizable.delete_withdraw_address(asset.symbol)
        }
        if let chainName = asset.depositNetworkName {
            subtitleLabel.text = chainName
            subtitleLabel.isHidden = false
            subtitlePlaceView.isHidden = false
        } else {
            subtitleLabel.isHidden = true
            subtitlePlaceView.isHidden = true
        }
        if TIP.status == .needsInitialize {
            passwordViewHeightConstraint.constant = 70
        } else {
            passwordViewHeightConstraint.constant = 60
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

    class func instance() -> LegacyAddressView {
        R.nib.legacyAddressView(withOwner: nil)!
    }
}

extension LegacyAddressView: PinFieldDelegate {

    func inputFinished(pin: String) {
        saveAddressAction(pin: pin)
    }

    private func saveAddressAction(pin: String) {
        dismissButton.isEnabled = false
        UIView.animate(withDuration: 0.15) {
            self.pinField.isHidden = true
            self.loadingView.isHidden = false
        }
        loadingView.startAnimating()

        if addressAction == .delete {
            guard let addressId = self.address?.addressId, let assetId = self.address?.assetId else {
                return
            }
            WithdrawalAPI.delete(addressId: addressId, pin: pin) { [weak self](result) in
                self?.processing = false
                switch result {
                case .success:
                    self?.pinField.resignFirstResponder()
                    AddressDAO.shared.deleteAddress(assetId: assetId, addressId: addressId)
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
                case let .failure(error):
                    PINVerificationFailureHandler.handle(error: error) { (description) in
                        self?.superView?.alert(description)
                        self?.superView?.dismissPopupController(animated: true)
                    }
                }
            }
        } else {
            addressRequest?.pin = pin
            guard let address = addressRequest else {
                return
            }
            WithdrawalAPI.save(address: address) { [weak self] (result) in
                self?.processing = false
                switch result {
                case let .success(address):
                    self?.pinField.resignFirstResponder()
                    AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.saved())
                case .failure(.malformedAddress):
                    guard let self = self else {
                        return
                    }
                    let message: String
                    if self.asset.isEOSChain {
                        message = R.string.localizable.invalid_malformed_address_eos_hint()
                    } else if self.asset.isERC20 {
                        message = R.string.localizable.invalid_malformed_address_hint("Ethereum(ERC20) \(self.asset.symbol)")
                    } else {
                        message = R.string.localizable.invalid_malformed_address_hint(self.asset.symbol)
                    }
                    self.superView?.alert(message)
                    self.superView?.dismissPopupController(animated: true)
                case let .failure(error):
                    guard let self = self else {
                        return
                    }
                    PINVerificationFailureHandler.handle(error: error) { (description) in
                        self.superView?.alert(description)
                        self.superView?.dismissPopupController(animated: true)
                    }
                }
            }
        }
    }
}

extension LegacyAddressView {

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
        UIView.animate(withDuration: duration, delay: 0, options: [options, .overdampedCurve]) {
            superView.contentBottomConstraint.constant = 0
            superView.alpha = 0
            superView.layoutIfNeeded()
        } completion: { _ in
            superView.isShowing = false
            superView.removeFromSuperview()
            self.dismissCallback?(true)
        }
    }

}
