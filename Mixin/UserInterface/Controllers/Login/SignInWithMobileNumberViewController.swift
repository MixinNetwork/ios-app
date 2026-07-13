import UIKit
import CoreTelephony
import Alamofire
import MixinServices

final class SignInWithMobileNumberViewController: MobileNumberViewController {
    
    private let cellularData = CTCellularData()
    
    private weak var signUpButton: UIButton!
    private weak var actionStackViewToKeyboardConstraint: NSLayoutConstraint!
    private weak var actionStackViewToSignUpConstraint: NSLayoutConstraint!
    
    private lazy var captcha = Captcha(viewController: self)
    
    private var isViewAppearing = false
    private var isBusy = false
    private var request: Request?
    
    private var isNetworkPermissionRestricted: Bool {
        cellularData.restrictedState == .restricted && !ReachabilityManger.shared.isReachable
    }
    
    init() {
        super.init(style: .secondary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [
            .customerService(target: self, action: #selector(presentCustomerService(_:))),
        ]
        
        declarationTextView.textColor = R.color.text_tertiary()
        declarationTextView.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        declarationTextView.adjustsFontForContentSizeCategory = true
        declarationTextView.text = R.string.localizable.login_method_mobile_desc()
        
        let signUpConfig: UIButton.Configuration = {
            var config: UIButton.Configuration = .filled()
            config.baseBackgroundColor = R.color.background()
            config.baseForegroundColor = R.color.theme()
            config.attributedTitle = AttributedString(
                string: R.string.localizable.sign_in_no_account(),
                scalingByFontSize: 16,
                weight: .medium
            )
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
            config.cornerStyle = .capsule
            return config
        }()
        let signUpButton = UIButton(configuration: signUpConfig)
        if let label = signUpButton.titleLabel {
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
        }
        contentView.addSubview(signUpButton)
        signUpButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.trailing.equalToSuperview().offset(-36)
            make.bottom.equalTo(contentView.snp.bottom).offset(-30)
            make.top.greaterThanOrEqualTo(actionStackView.snp.bottom).offset(10)
        }
        signUpButton.addTarget(self, action: #selector(signup(_:)), for: .touchUpInside)
        self.signUpButton = signUpButton
        
        let actionStackViewToKeyboardConstraint = actionStackView.bottomAnchor
            .constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -26)
        actionStackViewToKeyboardConstraint.priority = .almostInexist
        self.actionStackViewToKeyboardConstraint = actionStackViewToKeyboardConstraint
        
        let actionStackViewToSignUpConstraint = actionStackView.bottomAnchor
            .constraint(equalTo: signUpButton.topAnchor, constant: -16)
        actionStackViewToSignUpConstraint.priority = .almostRequired
        self.actionStackViewToSignUpConstraint = actionStackViewToSignUpConstraint
        
        NSLayoutConstraint.activate([
            actionStackViewToKeyboardConstraint,
            actionStackViewToSignUpConstraint,
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        textField.becomeFirstResponder()
        reporter.report(event: .loginStart)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewAppearing = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewAppearing = false
    }
    
    override func continueToNext(_ sender: Any) {
        let message = R.string.localizable.text_confirm_send_code(fullNumber(withSpacing: true))
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.change(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.confirm(), style: .default, handler: { _ in
            self.requestVerificationCode(captchaToken: nil)
            reporter.report(event: .loginSMSSendConfirmed)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "sign_in_phone_number"])
    }
    
    @objc private func signup(_ sender: Any) {
        let intro = CreateAccountIntroductionViewController(analyticSource: "login_start")
        present(intro, animated: true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        hideOtherOptions()
        actionStackViewToKeyboardConstraint.priority = .almostRequired
        actionStackViewToSignUpConstraint.priority = .almostInexist
        if isViewAppearing {
            view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        if !isBusy && presentedViewController == nil {
            showOtherOptions()
        }
        actionStackViewToKeyboardConstraint.priority = .almostInexist
        actionStackViewToSignUpConstraint.priority = .almostRequired
        view.layoutIfNeeded()
    }
    
}

extension SignInWithMobileNumberViewController: NavigationBarStyling {
    
    var navigationBarStyle: NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension SignInWithMobileNumberViewController: Captcha.Reporting {
    
    var reportingContent: (event: Reporter.Event, type: String?) {
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
                    var tags = ["type": "phone"]
                    if error.isServerErrorResponse {
                        tags["error_type"] = "server_error"
                    } else if error.isClientErrorResponse {
                        tags["error_type"] = "client_error"
                    }
                    if let statusCode = self.request?.response?.statusCode {
                        tags["error_code"] = "\(statusCode)"
                    }
                    reporter.report(event: .errorSessionVerifications, tags: tags)
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
        signUpButton.alpha = 0
    }
    
    private func showOtherOptions() {
        signUpButton.alpha = 1
    }
    
}
