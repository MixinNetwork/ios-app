import UIKit

class PinValidationViewController: UIViewController {
    
    typealias SuccessCallback = ((String) -> Void) // param is verified PIN
    typealias FailedCallback = (() -> Void)
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var loadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var limitationHintView: UIView!
    @IBOutlet weak var numberPadView: NumberPadView!
    
    @IBOutlet weak var numberPadViewBottomConstraint: NSLayoutConstraint!
    
    let presentationManager = PinValidationPresentationManager()
    
    private var onSuccess: SuccessCallback?
    private var onFailed: FailedCallback?
    
    convenience init(tips: String? = nil, onSuccess: SuccessCallback? = nil, onFailed: FailedCallback? = nil) {
        self.init(nib: R.nib.pinValidationView)
        if let tips = tips {
            loadViewIfNeeded()
            descriptionLabel.text = tips
        }
        self.onSuccess = onSuccess
        self.onFailed = onFailed
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        numberPadView.target = pinField
    }
    
    @IBAction func pinEditingChangedAction(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        loadingIndicator.startAnimating()
        pinField.isHidden = true
        pinField.receivesInput = false
        validate(pin: pinField.text)
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        onFailed?()
        dismiss(animated: true, completion: nil)
    }
    
    func validate(pin: String) {
        AccountAPI.shared.verify(pin: pin) { (result) in
            self.loadingIndicator.stopAnimating()
            switch result {
            case .success:
                let interval = min(PeriodicPinVerificationInterval.max, AppGroupUserDefaults.Wallet.periodicPinVerificationInterval * 2)
                AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = interval
                AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                self.onSuccess?(pin)
                self.dismiss(animated: true, completion: nil)
            case let .failure(error):
                if !pin.isNumeric || pin.trimmingCharacters(in: .whitespacesAndNewlines).count != 6 {
                    Reporter.report(error: MixinError.invalidPin)
                } else if error.status != NSURLErrorTimedOut {
                    Reporter.report(error: error)
                }
                self.handle(error: error)
            }
        }
    }
    
    func handle(error: APIError) {
        pinField.clear()
        pinField.receivesInput = true
        if error.code == 429 {
            limitationHintView.isHidden = false
            numberPadViewBottomConstraint.constant = numberPadView.frame.height
            UIView.animate(withDuration: 0.5, animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.layoutIfNeeded()
            })
        } else {
            pinField.isHidden = false
            descriptionLabel.textColor = .mixinRed
            descriptionLabel.text = error.localizedDescription
        }
    }
    
}
