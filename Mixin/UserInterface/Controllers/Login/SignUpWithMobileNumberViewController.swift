import UIKit
import CoreTelephony
import Alamofire
import MixinServices

class SignUpWithMobileNumberViewController: MobileNumberViewController {
    
    private let cellularData = CTCellularData()
    
    private lazy var captcha = Captcha(viewController: self)
    
    private var request: Request?
    
    private var isNetworkPermissionRestricted: Bool {
        cellularData.restrictedState == .restricted && !ReachabilityManger.shared.isReachable
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
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
    
    func setupView() {
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        textField.becomeFirstResponder()
        declarationTextView.attributedText = {
            let text = R.string.localizable.phone_as_key_shard()
            let paragraphSytle = NSMutableParagraphStyle()
            paragraphSytle.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 13)),
                .paragraphStyle: paragraphSytle,
                .foregroundColor: R.color.text_quaternary()!
            ]
            return NSAttributedString(string: text, attributes: attributes)
        }()
    }
    
    func updateViews(isBusy: Bool) {
        continueButton.isBusy = isBusy
    }
    
    func requestVerificationCode(captchaToken token: CaptchaToken?) {
        updateViews(isBusy: true)
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
                let context = PhoneNumberVerificationContext(
                    phoneNumber: phoneNumber,
                    displayPhoneNumber: displayPhoneNumber,
                    deactivation: verification.deactivation,
                    verificationID: verification.id,
                    hasEmergencyContact: verification.hasEmergencyContact
                )
                let vc = PhoneNumberLoginVerificationCodeViewController(context: context)
                self.navigationController?.pushViewController(vc, animated: true)
                self.updateViews(isBusy: false)
            case let .failure(error):
                switch error {
                case .requiresCaptcha:
                    captcha.validate { [weak self] (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(captchaToken: token)
                        default:
                            self?.updateViews(isBusy: false)
                        }
                    }
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
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
}
