import UIKit
import CoreTelephony
import Alamofire
import MixinServices

final class SignInWithMobileNumberViewController: MobileNumberViewController {
    
    private let cellularData = CTCellularData()
    private let separatorLineView = R.nib.loginSeparatorLineView(withOwner: nil)!
    private let mnemonicLoginButton = StyledButton(type: .system)
    private let signupButton = StyledButton(type: .system)
    
    private lazy var captcha = Captcha(viewController: self)
    
    private var isBusy = false
    private var request: Request?
    
    private var isNetworkPermissionRestricted: Bool {
        cellularData.restrictedState == .restricted && !ReachabilityManger.shared.isReachable
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [
            .customerService(target: self, action: #selector(presentCustomerService(_:))),
        ]
        
        declarationTextView.attributedText = .agreement()
        
        actionStackView.addArrangedSubview(separatorLineView)
        separatorLineView.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        
        mnemonicLoginButton.setTitle(R.string.localizable.sign_in_with_mnemonic_phrase(), for: .normal)
        mnemonicLoginButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        mnemonicLoginButton.style = .outline
        mnemonicLoginButton.applyDefaultContentInsets()
        actionStackView.addArrangedSubview(mnemonicLoginButton)
        mnemonicLoginButton.addTarget(self, action: #selector(mnemonicLogin(_:)), for: .touchUpInside)
        
        signupButton.setTitle(R.string.localizable.sign_in_no_account(), for: .normal)
        signupButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        signupButton.style = .tinted
        contentView.addSubview(signupButton)
        signupButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.trailing.equalToSuperview().offset(-36)
            make.bottom.equalTo(contentView.snp.bottom).offset(-30)
        }
        signupButton.applyDefaultContentInsets()
        signupButton.addTarget(self, action: #selector(signup(_:)), for: .touchUpInside)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func continueToNext(_ sender: Any) {
        let message = R.string.localizable.text_confirm_send_code(fullNumber(withSpacing: true))
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.change(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.confirm(), style: .default, handler: { _ in
            self.requestVerificationCode(captchaToken: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "sign_in_phone_number"])
    }
    
    @objc private func mnemonicLogin(_ sender: Any) {
        let signIn = SignInWithMnemonicsViewController()
        navigationController?.pushViewController(signIn, animated: true)
    }
    
    @objc private func signup(_ sender: Any) {
        let intro = CreateAccountIntroductionViewController()
        present(intro, animated: true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        hideOtherOptions()
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        if !isBusy && presentedViewController == nil {
            showOtherOptions()
        }
    }
    
}

extension SignInWithMobileNumberViewController: Captcha.Reporting {
    
    var reportingContent: (event: Reporter.Event, type: String) {
        (event: .loginCAPTCHA, type: "phone_number")
    }
    
}

extension SignInWithMobileNumberViewController {
    
    private func requestVerificationCode(captchaToken token: CaptchaToken?) {
        updateViews(isBusy: true)
        Logger.login.info(category: "SignUpWithMobileNumber", message: "Request code")
        let phoneNumber = fullNumber(withSpacing: false)
        let displayPhoneNumber = fullNumber(withSpacing: true)
        self.request = AccountAPI.sessionVerifications(
            phoneNumber: phoneNumber,
            captchaToken: token
        ) { [weak self] (result) in
            guard let self else {
                return
            }
            switch result {
            case let .success(verification):
                let context = MobileNumberLoginContext(
                    phoneNumber: phoneNumber,
                    displayPhoneNumber: displayPhoneNumber,
                    deactivation: verification.deactivation,
                    verificationID: verification.id,
                    hasEmergencyContact: verification.hasEmergencyContact
                )
                let verify = PhoneNumberLoginVerificationCodeViewController(context: context)
                self.navigationController?.pushViewController(verify, animated: true)
                self.updateViews(isBusy: false)
            case let .failure(.response(error)) where .requiresCaptcha ~= error:
                self.captcha.validate(errorDescription: error.description) { [weak self] (result) in
                    switch result {
                    case .success(let token):
                        self?.requestVerificationCode(captchaToken: token)
                    default:
                        self?.updateViews(isBusy: false)
                    }
                }
            case let .failure(error):
                Logger.login.error(category: "SignUpWithMobileNumber", message: "Failed: \(error)")
                switch error {
                case let .httpTransport(error):
                    guard let underlying = (error.underlyingError as NSError?), underlying.domain == NSURLErrorDomain else {
                        fallthrough
                    }
                    if underlying.code == NSURLErrorNotConnectedToInternet && self.isNetworkPermissionRestricted {
                        self.alertSettings(R.string.localizable.permission_denied_network_hint())
                        self.updateViews(isBusy: false)
                    } else {
                        fallthrough
                    }
                default:
                    reporter.report(event: .errorSessionVerifications, tags: ["source": "sign_up"])
                    var userInfo: [String: String] = [:]
                    userInfo["error"] = "\(error)"
                    if let requestId = self.request?.response?.value(forHTTPHeaderField: "x-request-id")  {
                        userInfo["requestId"] = requestId
                    }
                    if error.isTransportTimedOut {
                        userInfo["timeout"] = "yes"
                    } else if let statusCode = self.request?.response?.statusCode {
                        userInfo["statusCode"] = "\(statusCode)"
                    }
                    userInfo["phone"] = displayPhoneNumber
                    reporter.report(error: MixinError.requestLoginVerificationCode(userInfo))
                    self.alert(error.localizedDescription)
                    self.updateViews(isBusy: false)
                }
            }
        }
    }
    
    private func updateViews(isBusy: Bool) {
        self.isBusy = isBusy
        continueButton.isBusy = isBusy
        isBusy ? hideOtherOptions() : showOtherOptions()
    }
    
    private func hideOtherOptions() {
        separatorLineView.alpha = 0
        mnemonicLoginButton.alpha = 0
        signupButton.alpha = 0
    }
    
    private func showOtherOptions() {
        separatorLineView.alpha = 1
        mnemonicLoginButton.alpha = 1
        signupButton.alpha = 1
    }
    
}
