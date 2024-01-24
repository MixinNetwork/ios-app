import UIKit
import CoreTelephony
import SafariServices
import Alamofire
import MixinServices

final class LoginMobileNumberViewController: MobileNumberViewController {
    
    private let introTextView = IntroTextView()
    private let cellularData = CTCellularData()
    
    private var request: Request?
    
    private let intro: NSAttributedString = {
        let intro = R.string.localizable.agree_hint(R.string.localizable.terms_of_service(), R.string.localizable.privacy_policy())
        let nsIntro = intro as NSString
        let fullRange = NSRange(location: 0, length: nsIntro.length)
        let termsRange = nsIntro.range(of: R.string.localizable.terms_of_service())
        let privacyRange = nsIntro.range(of: R.string.localizable.privacy_policy())
        let attributedText = NSMutableAttributedString(string: intro)
        let paragraphSytle = NSMutableParagraphStyle()
        paragraphSytle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .paragraphStyle: paragraphSytle,
            .foregroundColor: R.color.text_tertiary()!
        ]
        attributedText.setAttributes(attrs, range: fullRange)
        attributedText.addAttributes([NSAttributedString.Key.link: URL.terms], range: termsRange)
        attributedText.addAttributes([NSAttributedString.Key.link: URL.privacy], range: privacyRange)
        return attributedText
    }()
    
    private var isNetworkPermissionRestricted: Bool {
        return cellularData.restrictedState == .restricted && !ReachabilityManger.shared.isReachable
    }
    
    deinit {
        CaptchaManager.shared.clean()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        introTextView.isScrollEnabled = false
        introTextView.attributedText = intro
        introTextView.isEditable = false
        introTextView.isSelectable = true
        introTextView.backgroundColor = .clear
        contentStackView.addArrangedSubview(introTextView)
        let customerServiceButton = UIButton(type: .system)
        customerServiceButton.tintColor = R.color.text()
        customerServiceButton.setImage(R.image.customer_service(), for: .normal)
        customerServiceButton.addTarget(self, action: #selector(requestCustomerService(_:)), for: .touchUpInside)
        view.addSubview(customerServiceButton)
        customerServiceButton.snp.makeConstraints { make in
            make.width.height.equalTo(44)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.trailing.equalToSuperview().offset(-8)
        }
    }
    
    override func continueAction(_ sender: Any) {
        let message = R.string.localizable.text_confirm_send_code(fullNumber(withSpacing: true))
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.change(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.confirm(), style: .default, handler: { _ in
            self.requestVerificationCode(captchaToken: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    override func updateViews(with country: Country) {
        super.updateViews(with: country)
        if country == .anonymous {
            titleLabel.text = R.string.localizable.enter_your_anonymous_number()
        } else {
            titleLabel.text = R.string.localizable.enter_your_phone_number()
        }
    }
    
    @objc private func requestCustomerService(_ sender: Any) {
        let customerService = SFSafariViewController(url: .customerService)
        present(customerService, animated: true)
    }
    
    private func requestVerificationCode(captchaToken token: CaptchaToken?) {
        continueButton.isBusy = true
        var ctx = LoginContext(callingCode: country.callingCode,
                               mobileNumber: mobileNumber,
                               fullNumber: fullNumber(withSpacing: false))
        self.request = AccountAPI.sendCode(to: ctx.fullNumber, captchaToken: token, purpose: .session) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(verification):
                ctx.verificationId = verification.id
                ctx.hasEmergencyContact = verification.hasEmergencyContact
                ctx.deactivatedAt = verification.deactivatedAt
                let vc = PhoneNumberLoginVerificationCodeViewController()
                vc.context = ctx
                weakSelf.navigationController?.pushViewController(vc, animated: true)
                weakSelf.continueButton.isBusy = false
            case let .failure(error):
                switch error {
                case .requiresCaptcha:
                    CaptchaManager.shared.validate(on: weakSelf, completion: { (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(captchaToken: token)
                        default:
                            self?.continueButton.isBusy = false
                        }
                    })
                case let .httpTransport(error):
                    guard let underlying = (error.underlyingError as NSError?), underlying.domain == NSURLErrorDomain else {
                        fallthrough
                    }
                    if underlying.code == NSURLErrorNotConnectedToInternet && weakSelf.isNetworkPermissionRestricted {
                        weakSelf.alertSettings(R.string.localizable.permission_denied_network_hint())
                        weakSelf.continueButton.isBusy = false
                    } else {
                        fallthrough
                    }
                default:
                    var userInfo: [String: String] = [:]
                    userInfo["error"] = "\(error)"
                    if let requestId = weakSelf.request?.response?.value(forHTTPHeaderField: "x-request-id")  {
                        userInfo["requestId"] = requestId
                    }
                    if error.isTransportTimedOut {
                        userInfo["timeout"] = "yes"
                    } else if let statusCode = weakSelf.request?.response?.statusCode {
                        userInfo["statusCode"] = "\(statusCode)"
                    }
                    userInfo["phone"] = ctx.mobileNumber
                    userInfo["phoneCountryCode"] = ctx.callingCode
                    reporter.report(error: MixinError.requestLoginVerificationCode(userInfo))
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.continueButton.isBusy = false
                }
            }
        }
    }
    
}
