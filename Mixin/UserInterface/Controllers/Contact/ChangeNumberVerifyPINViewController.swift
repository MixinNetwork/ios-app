import UIKit
import SwiftMessages

class ChangeNumberVerifyPINViewController: ChangeNumberViewController {

    @IBOutlet weak var pinField: PinField!
    
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
        bottomWrapperView.continueButton.isEnabled = canContinue
        if canContinue {
            continueAction(sender)
        }
    }

    override func continueAction(_ sender: Any) {
        bottomWrapperView.continueButton.isBusy = true
        pinField.receivesInput = false
        let pin = pinField.text
        context.pin = pin
        AccountAPI.shared.verify(pin: pin) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.bottomWrapperView.continueButton.isBusy = false
            weakSelf.pinField.receivesInput = true
            switch result {
            case .success:
                let vc = ChangeNumberNewNumberViewController.instance(context: weakSelf.context)
                weakSelf.navigationController?.pushViewController(vc, animated: true)
            case let .failure(error):
                weakSelf.pinField.clear()
                weakSelf.alert(error.localizedDescription)
            }
        }
    }

}
