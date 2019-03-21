import UIKit

class PinValidationViewController: KeyboardBasedLayoutViewController {
    
    typealias SuccessCallback = ((String) -> Void) // param is verified PIN
    typealias FailedCallback = (() -> Void)
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var limitationHintView: UIView!
    
    @IBOutlet weak var contentViewBottomConstraint: NSLayoutConstraint!
    
    private let presentationManager = PinValidationPresentationManager()
    
    private var onSuccess: SuccessCallback?
    private var onFailed: FailedCallback?
    
    class func instance(tips: String? = nil, onSuccess: SuccessCallback? = nil, onFailed: FailedCallback? = nil) -> PinValidationViewController {
        let vc = R.storyboard.wallet.pin_validation()!
        if let tips = tips {
            vc.loadViewIfNeeded()
            vc.descriptionLabel.text = tips
        }
        vc.onSuccess = onSuccess
        vc.onFailed = onFailed
        vc.transitioningDelegate = vc.presentationManager
        vc.modalPresentationStyle = .custom
        return vc
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pinField.becomeFirstResponder()
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let windowHeight = AppDelegate.current.window!.bounds.height
        contentViewBottomConstraint.constant = windowHeight - keyboardFrame.origin.y
        view.layoutIfNeeded()
    }
    
    @IBAction func pinEditingChangedAction(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        loadingIndicator.startAnimating()
        pinField.isHidden = true
        pinField.receivesInput = false
        let pin = pinField.text
        AccountAPI.shared.verify(pin: pin) { (result) in
            self.loadingIndicator.stopAnimating()
            switch result {
            case .success:
                if WalletUserDefault.shared.checkPinInterval < WalletUserDefault.shared.checkMaxInterval {
                    WalletUserDefault.shared.checkPinInterval *= 2
                }
                WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                self.onSuccess?(pin)
                self.pinField.resignFirstResponder()
                self.dismiss(animated: true, completion: nil)
            case let .failure(error):
                self.pinField.clear()
                self.pinField.receivesInput = true
                if error.code == 429 {
                    self.limitationHintView.isHidden = false
                    self.pinField.resignFirstResponder()
                } else {
                    self.pinField.isHidden = false
                    self.descriptionLabel.textColor = UIColor.red
                    self.descriptionLabel.text = error.localizedDescription
                }
            }
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        onFailed?()
        dismiss(animated: true, completion: nil)
    }
    
}
