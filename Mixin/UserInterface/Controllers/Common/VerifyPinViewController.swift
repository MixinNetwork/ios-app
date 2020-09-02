import UIKit
import MixinServices

class VerifyPinViewController: ContinueButtonViewController {
    
    @IBOutlet weak var pinField: PinField!
    
    private var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            pinField.receivesInput = !isBusy
        }
    }
    
    convenience init() {
        self.init(nib: R.nib.verifyPinView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pinField.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
    }
    
    @IBAction func pinFieldChangedAction(_ sender: Any) {
        let canContinue = pinField.text.count == pinField.numberOfDigits
        continueButton.isHidden = !canContinue
        if canContinue {
            continueAction(sender)
        }
    }
    
    override func continueAction(_ sender: Any) {
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
                weakSelf.alertPinError(error: error)
            }
        }
    }

    private func alertPinError(error: APIError) {
        error.pinErrorHandler { [weak self](errorMsg) in
            self?.alert(errorMsg)
        }
    }
    
    func pinIsVerified(pin: String) {
        
    }
    
}
