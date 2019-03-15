import UIKit

class ChangeNumberVerifyPinViewController: ContinueButtonViewController {
    
    @IBOutlet weak var pinField: PinField!
    
    private var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            pinField.receivesInput = !isBusy
        }
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
        var context = ChangeNumberContext()
        context.pin = pin
        AccountAPI.shared.verify(pin: pin) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.isBusy = false
            switch result {
            case .success:
                let vc = ChangeNumberNewNumberViewController.instance(context: context)
                weakSelf.navigationController?.pushViewController(vc, animated: true)
            case let .failure(error):
                weakSelf.pinField.clear()
                weakSelf.alert(error.localizedDescription)
            }
        }
    }
    
}
