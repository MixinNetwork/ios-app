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
    
    init() {
        let nib = R.nib.verificationCodeView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if ScreenHeight.current <= .short {
            contentStackView.spacing = 18
        }
        if let label = resendButton.titleLabel {
            label.setFont(scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular),
                          adjustForContentSize: true)
            label.adjustsFontForContentSizeCategory = true
        }
        resendButton.normalTitle = R.string.localizable.resend_code()
        let resendPendingCodeKey = R.string.localizable.resend_code_pending.key.withUTF8Buffer { (buffer) in
            String(bytes: buffer, encoding: .utf8)
        }
        if let resendPendingCodeKey {
            resendButton.pendingTitleTemplate = NSLocalizedString(resendPendingCodeKey, comment: "")
        }
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
        super.viewDidDisappear(animated)
        resendButton.releaseTimer()
    }
    
    @IBAction func verificationCodeFieldEditingChanged(_ sender: Any) {
        
    }
    
    @IBAction func resendAction(_ sender: Any) {
        resendButton.isBusy = true
        verificationCodeField.clear()
        requestVerificationCode(captchaToken: nil)
    }
    
    func requestVerificationCode(captchaToken token: CaptchaToken?) {
        
    }
    
    func handleVerificationCodeError(_ error: MixinAPIError) {
        isBusy = false
        switch error {
        case .invalidPhoneVerificationCode:
            verificationCodeField.clear()
            verificationCodeField.showError()
            alert(R.string.localizable.the_code_is_incorrect())
        default:
            reporter.report(error: error)
            alert(error.localizedDescription)
        }
    }
    
}
