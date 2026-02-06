import UIKit
import MixinServices

final class VerifyMobileNumberInputNumberViewController: MobileNumberViewController {
    
    private enum AccountError: Error {
        case invalidAnonymousSalt
    }
    
    private var context: MobileNumberVerificationContext
    
    private lazy var captcha = Captcha(viewController: self)
    
    init(context: MobileNumberVerificationContext) {
        self.context = context
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch context.intent {
        case .periodicVerification:
            callingCodeButton.isUserInteractionEnabled = false
            textField.isUserInteractionEnabled = false
            if let account = LoginManager.shared.account {
                assert(!account.isAnonymous, "No periodic verification for anonymous numbers")
                if let number = account.phone {
                    let text = (textField.text ?? "") as NSString
                    let range = NSRange(location: 0, length: text.length)
                    _ = textField(textField, shouldChangeCharactersIn: range, replacementString: number)
                }
            }
        case .addMobileNumber, .changeMobileNumber:
            textField.becomeFirstResponder()
        }
    }
    
    override func continueToNext(_ sender: Any) {
        continueButton.isBusy = true
        context.newNumber = fullNumber(withSpacing: false)
        context.newNumberRepresentation = fullNumber(withSpacing: true)
        Task { [pin=context.pin, weak self] in
            do {
                guard let account = LoginManager.shared.account else {
                    return
                }
                guard let pinToken = AppGroupKeychain.pinToken else {
                    throw TIP.Error.missingPINToken
                }
                if account.isAnonymous {
                    let salt = try await TIP.custodialSalt(pin: pin)
                    let isSaltLegal = salt.allSatisfy { byte in
                        byte == 0x00
                    }
                    if !isSaltLegal {
                        throw AccountError.invalidAnonymousSalt
                    }
                }
                let encryptedSalt = try await TIP.encryptedSalt(pin: pin)
                let pinTokenEncryptedSalt = try AESCryptor.encrypt(encryptedSalt, with: pinToken)
                let base64Salt = pinTokenEncryptedSalt.base64RawURLEncodedString()
                await MainActor.run {
                    self?.requestVerificationCode(base64Salt: base64Salt, captchaToken: nil)
                }
            } catch {
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.alert(error.localizedDescription)
                    self.continueButton.isBusy = false
                }
            }
        }
    }
    
    override func updateViews(with country: Country) {
        super.updateViews(with: country)
        switch context.intent {
        case .periodicVerification:
            titleLabel.text = R.string.localizable.confirm_your_mobile_number()
        case .addMobileNumber, .changeMobileNumber:
            if country == .anonymous {
                titleLabel.text = R.string.localizable.enter_new_anonymous_number()
            } else {
                titleLabel.text = R.string.localizable.enter_new_phone_number()
            }
        }
    }
    
    private func requestVerificationCode(base64Salt: String, captchaToken token: CaptchaToken?) {
        var context = self.context
        AccountAPI.phoneVerifications(
            phoneNumber: context.newNumber,
            purpose: context.intent.verificationPurpose,
            base64Salt: base64Salt,
            captchaToken: token
        ) { [weak self] (result) in
            guard let self else {
                return
            }
            switch result {
            case .success(let verification):
                context.verificationID = verification.id
                context.base64Salt = base64Salt
                let oneTimeCode = VerifyMobileNumberOneTimeCodeViewController(context: context)
                self.navigationController?.pushViewController(oneTimeCode, animated: true)
                self.continueButton.isBusy = false
            case let .failure(.response(error)) where .requiresCaptcha ~= error:
                self.captcha.validate(errorDescription: error.description) { [weak self] (result) in
                    switch result {
                    case .success(let token):
                        self?.requestVerificationCode(base64Salt: base64Salt, captchaToken: token)
                    default:
                        self?.continueButton.isBusy = false
                    }
                }
            case let .failure(error):
                self.alert(error.localizedDescription)
                self.continueButton.isBusy = false
            }
        }
    }
    
}
