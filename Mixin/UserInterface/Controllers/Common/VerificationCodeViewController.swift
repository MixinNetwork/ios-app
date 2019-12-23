import UIKit
import MixinServices

class VerificationCodeViewController: ContinueButtonViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var verificationCodeField: VerificationCodeField!
    @IBOutlet weak var resendButton: CountDownButton!
    
    let resendInterval = 60
    
    var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            verificationCodeField.receivesInput = !isBusy
        }
    }
    
    convenience init() {
        self.init(nib: R.nib.verificationCodeView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if ScreenSize.current == .inch3_5 {
            contentStackView.spacing = 12
        } else if ScreenSize.current == .inch4 {
            contentStackView.spacing = 18
        }
        resendButton.normalTitle = Localized.BUTTON_TITLE_RESEND_CODE
        resendButton.pendingTitleTemplate = Localized.BUTTON_TITLE_RESEND_CODE_PENDING
        resendButton.beginCountDown(resendInterval)
        verificationCodeField.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !verificationCodeField.isFirstResponder {
            verificationCodeField.becomeFirstResponder()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resendButton.restartTimerIfNeeded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resendButton.releaseTimer()
    }
    
    @IBAction func verificationCodeFieldEditingChanged(_ sender: Any) {
        
    }
    
    @IBAction func resendAction(_ sender: Any) {
        resendButton.isBusy = true
        verificationCodeField.clear()
        requestVerificationCode(reCaptchaToken: nil)
    }
    
    func requestVerificationCode(reCaptchaToken token: String?) {
        
    }
    
    func handleVerificationCodeError(_ error: APIError) {
        isBusy = false
        if error.code == 20113 {
            verificationCodeField.clear()
            verificationCodeField.showError()
            alert(Localized.TEXT_INVALID_VERIFICATION_CODE)
        } else {
            Reporter.report(error: error)
            alert(error.localizedDescription)
        }
    }
    
}
