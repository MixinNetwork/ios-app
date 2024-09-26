import UIKit
import MixinServices

class MobileNumberViewController: ContinueButtonViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleWrapperStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var callingCodeButton: UIButton!
    
    private let invertedPhoneNumberCharacterSet = CharacterSet(charactersIn: "0123456789+-() ").inverted
    private let countryLibrary = CountryLibrary()
    
    private var stopLayoutWithKeyboard = false
    
    var mobileNumber: String {
        return textField.text?.components(separatedBy: invertedPhoneNumberCharacterSet).joined() ?? ""
    }
    
    var country: Country {
        didSet {
            updateViews(with: country)
        }
    }
    
    required init?(coder: NSCoder) {
        self.country = countryLibrary.deviceCountry
        super.init(coder: coder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.country = countryLibrary.deviceCountry
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    convenience init() {
        let nib = R.nib.mobileNumberView
        self.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews(with: country)
        textField.delegate = self
        textField.becomeFirstResponder()
        
        // UIButton with image and title failed to calculate intrinsicContentSize if bold text is turned on in iOS Display Settings
        // Set `lineBreakMode` to `byClipping` as a workaround. Confirmed on iOS 16.1
        callingCodeButton.titleLabel?.lineBreakMode = .byClipping
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !textField.isFirstResponder {
            textField.becomeFirstResponder()
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        guard !stopLayoutWithKeyboard else {
            return
        }
        super.layout(for: keyboardFrame)
    }
    
    @IBAction func selectCountryAction(_ sender: Any) {
        stopLayoutWithKeyboard = true
        let vc = SelectCountryViewController.instance(library: countryLibrary, selectedCountry: country)
        vc.delegate = self
        present(vc, animated: true, completion: nil)
    }
    
    @IBAction func textFieldEditingChangedAction(_ sender: Any) {
        updateContinueButtonIsHidden()
    }
    
    func fullNumber(withSpacing: Bool) -> String {
        return "+" + country.callingCode + (withSpacing ? " " : "") + mobileNumber
    }
    
    func updateViews(with country: Country) {
        let image = UIImage(named: country.isoRegionCode.lowercased())
        callingCodeButton.setImage(image, for: .normal)
        callingCodeButton.setTitle("+\(country.callingCode)", for: .normal)
        
        if country == .anonymous {
            textField.placeholder = R.string.localizable.anonymous_number()
        } else {
            textField.placeholder = R.string.localizable.phone_number()
        }
    }
    
    private func updateContinueButtonIsHidden() {
        let isNumberValid: Bool
        if country == .anonymous {
            isNumberValid = !mobileNumber.isEmpty && mobileNumber.isDigitsOnly
        } else {
            isNumberValid = PhoneNumberValidator.global.isValid(callingCode: country.callingCode, number: mobileNumber)
        }
        continueButton.isHidden = !isNumberValid
    }
    
}

extension MobileNumberViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        let numericsInText = newText.digits()
        if newText != numericsInText,
           let parsedPhoneNumber = try? PhoneNumberValidator.global.utility.parse(newText),
           let country = countryLibrary.countries.first(where: { $0.callingCode == String(parsedPhoneNumber.countryCode) })
        {
            self.country = country
            textField.text = parsedPhoneNumber.adjustedNationalNumber()
            textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
            updateContinueButtonIsHidden()
            return false
        } else {
            return true
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if !continueButton.isHidden {
            continueAction(textField)
        }
        return false
    }
    
}

extension MobileNumberViewController: SelectCountryViewControllerDelegate {
    
    func selectCountryViewController(_ viewController: SelectCountryViewController, didSelectCountry country: Country) {
        self.stopLayoutWithKeyboard = false
        dismiss(animated: true, completion: nil)
        self.country = country
        updateContinueButtonIsHidden()
    }
    
}
