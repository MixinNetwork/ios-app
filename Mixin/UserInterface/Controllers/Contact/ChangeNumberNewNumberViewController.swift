import UIKit
import PhoneNumberKit

class ChangeNumberNewNumberViewController: ChangeNumberViewController {
    
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
            mobileNumberTextField.layoutIfNeeded()
        }
    }
    
    deinit {
        ReCaptchaManager.shared.clean()
    }
    
    override func continueAction(_ sender: Any) {
        bottomWrapperView.continueButton?.isBusy = true
        let phoneNumber = fullNumber(withSpacing: false)
        context.newNumber = phoneNumber
        context.newNumberRepresentation = fullNumber(withSpacing: true)
        sendCode(phoneNumber: phoneNumber, reCaptchaToken: nil)
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
        bottomWrapperView.continueButton.isEnabled = numberIsLegal
    }

    @IBAction func mobileNumberEditingEndAction(_ sender: Any) {
        mobileNumberTextField.layoutIfNeeded()
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
    
    private func sendCode(phoneNumber: String, reCaptchaToken token: String?) {
        AccountAPI.shared.sendCode(to: phoneNumber, reCaptchaToken: token, purpose: .phone) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let verification):
                weakSelf.context.verificationId = verification.id
                let vc = ChangeNumberVerificationCodeViewController.instance(context: weakSelf.context)
                weakSelf.navigationController?.pushViewController(vc, animated: true)
                weakSelf.bottomWrapperView.continueButton?.isBusy = false
            case let .failure(error):
                if error.code == 10005 {
                    ReCaptchaManager.shared.validate(onViewController: weakSelf) { (result) in
                        switch result {
                        case .success(let token):
                            self?.sendCode(phoneNumber: phoneNumber, reCaptchaToken: token)
                        default:
                            self?.bottomWrapperView.continueButton?.isBusy = false
                        }
                    }
                } else {
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.bottomWrapperView.continueButton?.isBusy = false
                }
            }
        }
    }
    
    class func instance(context: ChangeNumberContext) -> ChangeNumberNewNumberViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "new_number") as! ChangeNumberNewNumberViewController
        vc.context = context
        return vc
    }
    
}

extension ChangeNumberNewNumberViewController: SelectCountryViewControllerDelegate {
    
    func selectCountryViewController(_ viewController: SelectCountryViewController, didSelectCountry country: Country) {
        self.country = country
        updateContinueButtonStatusAction(self)
        viewController.dismiss(animated: true, completion: nil)
    }
    
}
