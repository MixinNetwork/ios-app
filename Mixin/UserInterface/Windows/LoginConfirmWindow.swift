import UIKit
import MixinServices

class LoginConfirmWindow: BottomSheetView {

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var numberPadView: NumberPadView!
    @IBOutlet weak var loadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var biometricButton: UIButton!
    
    @IBOutlet weak var showBiometricButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideBiometricButtonConstraint: NSLayoutConstraint!
    
    private var id: String!
    private var publicKey: String!
    private var isAutoFillPIN = false
    
    private var canAuthorizeWithBiometric: Bool {
        guard AppGroupUserDefaults.Wallet.payWithBiometricAuthentication else {
            return false
        }
        guard biometryType != .none else {
            return false
        }
        return true
    }
    
    private lazy var biometricAuthQueue = DispatchQueue(label: "one.mixin.messenger.LoginConfirmWindow.BioAuth")

    @IBAction func pinEditingChangedAction(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        loadingIndicator.startAnimating()
        pinField.isHidden = true
        pinField.receivesInput = false
        
        func handleError(error: MixinAPIError?) {
            loadingIndicator.stopAnimating()
            pinField.clear()
            pinField.isHidden = false
            pinField.receivesInput = true
            if let error {
                if case .forbidden = error {
                    alert(error.localizedDescription)
                    dismissPopupController(animated: true)
                } else {
                    PINVerificationFailureHandler.handle(error: error) { description in
                        self.alert(description)
                    }
                }
            }
        }
        
        guard let identityKeyPair = try? PreKeyUtil.getIdentityKeyPair(), let account = LoginManager.shared.account else {
            handleError(error: nil)
            return
        }
        ProvisioningAPI.code { (response) in
            switch response {
            case .success(let response):
                let message = ProvisionMessage(identityKeyPublic: identityKeyPair.publicKey,
                                               identityKeyPrivate: identityKeyPair.privateKey,
                                               userId: account.userID,
                                               sessionId: account.sessionID,
                                               provisioningCode: response.code)
                guard let secretData = try? message.encrypt(with: self.publicKey) else {
                    handleError(error: nil)
                    return
                }
                let secret = secretData.base64EncodedString()
                ProvisioningAPI.update(id: self.id, secret: secret, pin: self.pinField.text, completion: { (result) in
                    switch result {
                    case .success:
                        if !self.isAutoFillPIN {
                            AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                        }
                        self.dismissView()
                        showAutoHiddenHud(style: .notification, text: R.string.localizable.logined())
                    case .failure(let error):
                        handleError(error: error)
                    }
                })
            case .failure(let error):
                handleError(error: error)
            }
        }
    }
    
    @IBAction func biometricAction(_ sender: Any) {
        let prompt = R.string.localizable.authorize_desktop_login(biometryType.localizedName)
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
        dismissView()
    }

    func render(id: String, publicKey: String) -> LoginConfirmWindow {
        self.id = id
        self.publicKey = publicKey
        numberPadView.target = pinField
        if canAuthorizeWithBiometric {
            let image = biometryType == .faceID ? R.image.ic_pay_face() : R.image.ic_pay_touch()
            biometricButton.setImage(image, for: .normal)
            biometricButton.setTitle(R.string.localizable.use_biometry(biometryType.localizedName), for: .normal)
            hideBiometricButtonConstraint.priority = .defaultLow
            showBiometricButtonConstraint.priority = .defaultHigh
            biometricButton.isHidden = false
        } else {
            hideBiometricButtonConstraint.priority = .defaultHigh
            showBiometricButtonConstraint.priority = .defaultLow
            biometricButton.isHidden = true
        }
        return self
    }
    
    class func instance() -> LoginConfirmWindow {
        R.nib.loginConfirmWindow(owner: self)!
    }
    
}
