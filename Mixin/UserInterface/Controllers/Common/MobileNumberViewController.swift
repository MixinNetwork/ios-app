import UIKit
import PhoneNumberKit

class MobileNumberViewController: ContinueButtonViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var callingCodeButton: UIButton!
    
    private let phoneNumberKit = PhoneNumberKit()
    private let invertedPhoneNumberCharacterSet = CharacterSet(charactersIn: "0123456789+-() ").inverted
    
    var mobileNumber: String {
        return textField.text?.components(separatedBy: invertedPhoneNumberCharacterSet).joined() ?? ""
    }
    
    var country = CountryCodeLibrary.shared.deviceCountry {
        didSet {
            updateCallingCodeButtonCaption()
        }
    }
    
    convenience init() {
        self.init(nib: R.nib.mobileNumberView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateCallingCodeButtonCaption()
        textField.delegate = self
        textField.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !textField.isFirstResponder {
            textField.becomeFirstResponder()
        }
    }
    
    @IBAction func selectCountryAction(_ sender: Any) {
        let vc = SelectCountryViewController.instance(selectedCountry: country)
        vc.delegate = self
        present(vc, animated: true, completion: nil)
    }
    
    @IBAction func textFieldEditingChangedAction(_ sender: Any) {
        updateContinueButtonIsHidden()
    }
    
    func fullNumber(withSpacing: Bool) -> String {
        return "+" + country.callingCode + (withSpacing ? " " : "") + mobileNumber
    }
    
}

extension MobileNumberViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        let numericsInText = newText.digits()
        if newText != numericsInText, let parsedPhoneNumber = try? phoneNumberKit.parse(newText), let country = CountryCodeLibrary.shared.countries.first(where: { $0.callingCode == String(parsedPhoneNumber.countryCode) }) {
            self.country = country
            textField.text = parsedPhoneNumber.adjustedNationalNumber()
            return false
        } else {
            return true
        }
    }
    
}

extension MobileNumberViewController: SelectCountryViewControllerDelegate {
    
    func selectCountryViewController(_ viewController: SelectCountryViewController, didSelectCountry country: Country) {
        self.country = country
        updateContinueButtonIsHidden()
        viewController.dismiss(animated: true, completion: nil)
    }
    
}

extension MobileNumberViewController {
    
    private func updateCallingCodeButtonCaption() {
        let image = UIImage(named: country.isoRegionCode.lowercased())
        callingCodeButton.setImage(image, for: .normal)
        callingCodeButton.setTitle("+\(country.callingCode)", for: .normal)
    }
    
    private func updateContinueButtonIsHidden() {
        let numberIsLegal = (try? phoneNumberKit.parse(fullNumber(withSpacing: false))) != nil
        continueButton.isHidden = !numberIsLegal
    }
    
}
