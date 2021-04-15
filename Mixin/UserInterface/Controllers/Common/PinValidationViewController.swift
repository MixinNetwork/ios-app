import UIKit
import MixinServices

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
        AccountAPI.verify(pin: pin) { (result) in
            switch result {
            case .success:
                self.loadingIndicator.stopAnimating()
                let interval = min(PeriodicPinVerificationInterval.max, AppGroupUserDefaults.Wallet.periodicPinVerificationInterval * 2)
                AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = interval
                AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                self.onSuccess?(pin)
                self.dismiss(animated: true, completion: nil)
            case let .failure(error):
                if !pin.isNumeric || pin.trimmingCharacters(in: .whitespacesAndNewlines).count != 6 {
                    reporter.report(error: MixinError.invalidPin)
                } else if !error.isTransportTimedOut {
                    reporter.report(error: error)
                }
                self.handle(error: error)
            }
        }
    }
    
    func handle(error: MixinAPIError) {
        pinField.clear()
        pinField.receivesInput = true
        switch error {
        case .tooManyRequests:
            self.loadingIndicator.stopAnimating()
            limitationHintView.isHidden = false
            descriptionLabel.isHidden = true
            numberPadViewBottomConstraint.constant = numberPadView.frame.height
            UIView.animate(withDuration: 0.5, animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.layoutIfNeeded()
            })
        default:
            PINVerificationFailureHandler.handle(error: error) { (description) in
                self.loadingIndicator.stopAnimating()
                self.pinField.isHidden = false
                self.descriptionLabel.textColor = .mixinRed
                self.descriptionLabel.text = description
            }
        }
    }
    
}
