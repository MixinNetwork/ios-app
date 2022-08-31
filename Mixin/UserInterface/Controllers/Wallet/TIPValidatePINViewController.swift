import UIKit
import MixinServices

class TIPValidatePINViewController: PinValidationViewController {
    
    enum Action {
        case create((_ pin: String) -> Void)
        case change((_ old: String, _ new: String) -> Void)
    }
    
    private let action: Action
    
    private var oldPIN: String?
    
    init(action: Action) {
        self.action = action
        let nib = R.nib.pinValidationView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch action {
        case .create:
            titleLabel.text = R.string.localizable.enter_your_pin()
        case .change:
            if oldPIN == nil {
                titleLabel.text = "Enter your old PIN"
            } else {
                titleLabel.text = "Enter your new PIN"
            }
        }
    }
    
    override func validate(pin: String) {
        switch action {
        case .create(let completion):
            presentingViewController?.dismiss(animated: true) {
                completion(pin)
            }
        case .change(let completion):
            if let oldPIN = oldPIN {
                presentingViewController?.dismiss(animated: true) {
                    completion(oldPIN, pin)
                }
            } else {
                AccountAPI.verify(pin: pin) { result in
                    switch result {
                    case .success:
                        self.titleLabel.text = "Enter your new PIN"
                        self.pinField.clear()
                        self.pinField.isHidden = false
                        self.pinField.receivesInput = true
                        self.loadingIndicator.stopAnimating()
                        self.oldPIN = pin
                    case .failure(let error):
                        self.handle(error: error)
                    }
                }
            }
        }
    }
    
}
