import UIKit
import PhoneNumberKit

class MobileNumberViewController: LoginViewController {

    @IBOutlet weak var mobileNumberTextField: UITextField!
    @IBOutlet weak var callingCodeButton: UIButton!

    private let phoneNumberKit = PhoneNumberKit()
    private let invertedPhoneNumberCharacterSet = CharacterSet(charactersIn: "0123456789+-() ").inverted
    
    private var country = CountryCodeLibrary.shared.deviceCountry {
        didSet {
            updateCallingCodeButtonCaption()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateCallingCodeButtonCaption()
        mobileNumberTextField.becomeFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !mobileNumberTextField.isFirstResponder {
            mobileNumberTextField.becomeFirstResponder()
        }
    }
    
    deinit {
        ReCaptchaManager.shared.clean()
    }
    
    @IBAction func selectCountryAction(_ sender: Any) {
        let vc = SelectCountryViewController.instance(selectedCountry: country)
        vc.delegate = self
        present(vc, animated: true, completion: nil)
    }
    
    @IBAction func updateContinueButtonStatusAction(_ sender: Any) {
        let numericsInText = mobileNumber.digits()
        if mobileNumber != numericsInText {
            if let parsedPhoneNumber = try? phoneNumberKit.parse(mobileNumber), let country = CountryCodeLibrary.shared.countries.first(where: { $0.callingCode == String(parsedPhoneNumber.countryCode) }) {
                self.country = country
                mobileNumberTextField.text = parsedPhoneNumber.adjustedNationalNumber()
            } else {
                mobileNumberTextField.text = numericsInText
            }
        }
        DispatchQueue.main.async {
            let endPosition = self.mobileNumberTextField.endOfDocument
            self.mobileNumberTextField.selectedTextRange = self.mobileNumberTextField.textRange(from: endPosition, to: endPosition)
        }
        let numberIsLegal = (try? phoneNumberKit.parse(fullNumber(withSpacing: false))) != nil
        continueButton.isEnabled = numberIsLegal
    }
    
    @IBAction func mobileNumberEditingEndAction(_ sender: Any) {
        mobileNumberTextField.layoutIfNeeded()
    }
    
    override func continueAction(_ sender: Any) {
        let message = String(format: Localized.TEXT_CONFIRM_SEND_CODE, fullNumber(withSpacing: true))
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CHANGE, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CONFIRM, style: .default, handler: { [weak self](action) in
            self?.checkMobileNumber()
        }))

        if let window = UIApplication.shared.windows.last, window.windowLevel == 10000001.0 {
            window.rootViewController?.present(alert, animated: true, completion: nil)
        } else {
            present(alert, animated: true, completion: nil)
        }
    }
    
    private var mobileNumber: String {
        return mobileNumberTextField.text?.components(separatedBy: invertedPhoneNumberCharacterSet).joined() ?? ""
    }
    
    private func fullNumber(withSpacing: Bool) -> String {
        return "+" + country.callingCode + (withSpacing ? " " : "") + mobileNumber
    }
    
    private func updateCallingCodeButtonCaption() {
        let image = UIImage(named: country.isoRegionCode.lowercased())
        callingCodeButton.setImage(image, for: .normal)
        callingCodeButton.setTitle("+\(country.callingCode)", for: .normal)
    }
    
    private func checkMobileNumber() {
        continueButton.isBusy = true
        sendCode(reCaptchaToken: nil)
    }
    
    private func sendCode(reCaptchaToken token: String?) {
        var loginInfo = LoginInfo(callingCode: country.callingCode,
                                  mobileNumber: mobileNumber,
                                  fullNumber: fullNumber(withSpacing: false),
                                  verificationId: nil)
        AccountAPI.shared.sendCode(to: fullNumber(withSpacing: false), reCaptchaToken: token, purpose: .session) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(verification):
                loginInfo.verificationId = verification.id
                let vc = VerificationCodeViewController.instance(loginInfo: loginInfo)
                weakSelf.navigationController?.pushViewController(vc, animated: true)
                weakSelf.continueButton.isBusy = false
            case let .failure(error):
                if error.code == 10005 {
                    ReCaptchaManager.shared.validate(onViewController: weakSelf, completion: { (result) in
                        switch result {
                        case .success(let token):
                            self?.sendCode(reCaptchaToken: token)
                        default:
                            self?.continueButton.isBusy = false
                        }
                    })
                } else {
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.continueButton.isBusy = false
                }
            }
        }
    }
    
}

extension MobileNumberViewController: SelectCountryViewControllerDelegate {
    
    func selectCountryViewController(_ viewController: SelectCountryViewController, didSelectCountry country: Country) {
        self.country = country
        updateContinueButtonStatusAction(self)
        viewController.dismiss(animated: true, completion: nil)
    }
    
}
