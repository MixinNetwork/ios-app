import UIKit

class MobileNumberViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var inputBoxView: UIView!
    @IBOutlet weak var callingCodeImageView: UIImageView!
    @IBOutlet weak var callingCodeButton: UIButton!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var declarationTextView: UITextView!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var continueButton: StyledButton!
    
    private let countryLibrary = CountryLibrary()
    private let invertedPhoneNumberCharacterSet = CharacterSet(charactersIn: "0123456789+-() ").inverted
    
    var mobileNumber: String {
        textField.text?.components(separatedBy: invertedPhoneNumberCharacterSet).joined() ?? ""
    }
    
    var country: Country {
        didSet {
            updateViews(with: country)
        }
    }
    
    init() {
        self.country = countryLibrary.deviceCountry
        let nib = R.nib.mobileNumberView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.sign_with_mobile_number()
        inputBoxView.layer.cornerRadius = 8
        inputBoxView.layer.masksToBounds = true
        updateViews(with: country)
        textField.delegate = self
        continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        continueButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        continueButton.style = .filled
    }
    
    @IBAction func changeCallingCode(_ sender: Any) {
        let selector = SelectCountryViewController(library: countryLibrary, selectedCountry: country)
        selector.delegate = self
        present(selector, animated: true, completion: nil)
    }
    
    @IBAction func validateMobileNumber(_ sender: Any) {
        let isNumberValid = if country == .anonymous {
            !mobileNumber.isEmpty && mobileNumber.isDigitsOnly
        } else {
            PhoneNumberValidator.global.isValid(callingCode: country.callingCode, number: mobileNumber)
        }
        continueButton.isEnabled = isNumberValid
    }
    
    @IBAction func continueToNext(_ sender: Any) {
        
    }
    
    func fullNumber(withSpacing: Bool) -> String {
        "+" + country.callingCode + (withSpacing ? " " : "") + mobileNumber
    }
    
    func updateViews(with country: Country) {
        let image = UIImage(named: country.isoRegionCode.lowercased())
        callingCodeImageView.image = image
        callingCodeButton.setTitle("+\(country.callingCode)", for: .normal)
        if country == .anonymous {
            textField.placeholder = R.string.localizable.anonymous_number()
        } else {
            textField.placeholder = R.string.localizable.phone_number()
        }
    }
    
}

extension MobileNumberViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = (textField.text ?? "") as NSString
        let newText = text.replacingCharacters(in: range, with: string)
        let numericsInText = newText.digits()
        if newText != numericsInText,
           let parsedPhoneNumber = try? PhoneNumberValidator.global.utility.parse(newText),
           let country = countryLibrary.countries.first(where: { $0.callingCode == String(parsedPhoneNumber.countryCode) })
        {
            self.country = country
            textField.text = parsedPhoneNumber.adjustedNationalNumber()
            textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
            validateMobileNumber(textField)
            return false
        } else {
            return true
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if continueButton.isEnabled {
            continueToNext(textField)
        }
        return false
    }
    
}

extension MobileNumberViewController: SelectCountryViewControllerDelegate {
    
    func selectCountryViewController(_ viewController: SelectCountryViewController, didSelectCountry country: Country) {
        dismiss(animated: true, completion: nil)
        self.country = country
        validateMobileNumber(viewController)
    }
    
}
