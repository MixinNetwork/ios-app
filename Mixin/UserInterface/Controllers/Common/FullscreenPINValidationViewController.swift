import UIKit
import MixinServices

class FullscreenPINValidationViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var continueButton: StyledButton!
    
    @IBOutlet weak var continueButtonBottomConstraint: NSLayoutConstraint!
    
    var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            pinField.receivesInput = !isBusy
        }
    }
    
    init() {
        let nib = R.nib.fullscreenPINValidationView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pinField.becomeFirstResponder()
        continueButton.style = .filled
        continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        continueButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        continueButtonBottomConstraint.constant = keyboardFrame.height + 20
        view.layoutIfNeeded()
    }
    
    @IBAction func pinFieldChangedAction(_ sender: Any) {
        let canContinue = pinField.text.count == pinField.numberOfDigits
        continueButton.isEnabled = canContinue
        if canContinue {
            continueAction(sender)
        }
    }
    
    @IBAction func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        AccountAPI.verify(pin: pin) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.isBusy = false
            switch result {
            case .success:
                weakSelf.pinIsVerified(pin: pin)
            case let .failure(error):
                weakSelf.pinField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description)
                }
            }
        }
    }
    
    func pinIsVerified(pin: String) {
        
    }
    
}
