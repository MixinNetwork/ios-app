import UIKit
import Alamofire
import CoreTelephony

final class LoginMobileNumberViewController: MobileNumberViewController {
    
    private let introTextView = IntroTextView()
    private let cellularData = CTCellularData()
    
    private var request: Request?
    
    private let intro: NSAttributedString = {
        let intro = String(format: Localized.TEXT_INTRO,
                           Localized.BUTTON_TITLE_TERMS_OF_SERVICE,
                           Localized.BUTTON_TITLE_PRIVACY_POLICY)
        let nsIntro = intro as NSString
        let fullRange = NSRange(location: 0, length: nsIntro.length)
        let termsRange = nsIntro.range(of: Localized.BUTTON_TITLE_TERMS_OF_SERVICE)
        let privacyRange = nsIntro.range(of: Localized.BUTTON_TITLE_PRIVACY_POLICY)
        let attributedText = NSMutableAttributedString(string: intro)
        let paragraphSytle = NSMutableParagraphStyle()
        paragraphSytle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .paragraphStyle: paragraphSytle,
            .foregroundColor: UIColor.accessoryText
        ]
        attributedText.setAttributes(attrs, range: fullRange)
        attributedText.addAttributes([NSAttributedString.Key.link: URL.terms], range: termsRange)
        attributedText.addAttributes([NSAttributedString.Key.link: URL.privacy], range: privacyRange)
        return attributedText
    }()
    
    private var isNetworkPermissionRestricted: Bool {
        return cellularData.restrictedState == .restricted && !NetworkManager.shared.isReachable
    }
    
    deinit {
        ReCaptchaManager.shared.clean()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        introTextView.isScrollEnabled = false
        introTextView.attributedText = intro
        introTextView.isEditable = false
        introTextView.isSelectable = true
        introTextView.backgroundColor = .clear
        contentStackView.addArrangedSubview(introTextView)
    }
    
    override func continueAction(_ sender: Any) {
        let message = String(format: Localized.TEXT_CONFIRM_SEND_CODE, fullNumber(withSpacing: true))
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CHANGE, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CONFIRM, style: .default, handler: { _ in
            self.requestVerificationCode()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func requestVerificationCode(reCaptchaToken token: String? = nil) {
        continueButton.isBusy = true
        var ctx = LoginContext(callingCode: country.callingCode,
                               mobileNumber: mobileNumber,
                               fullNumber: fullNumber(withSpacing: false))
        self.request = AccountAPI.shared.sendCode(to: ctx.fullNumber, reCaptchaToken: token, purpose: .session) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(verification):
                ctx.verificationId = verification.id
                ctx.hasEmergencyContact = verification.hasEmergencyContact
                let vc = PhoneNumberLoginVerificationCodeViewController()
                vc.context = ctx
                weakSelf.navigationController?.pushViewController(vc, animated: true)
                weakSelf.continueButton.isBusy = false
            case let .failure(error):
                if error.code == 10005 {
                    ReCaptchaManager.shared.validate(onViewController: weakSelf, completion: { (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(reCaptchaToken: token)
                        default:
                            self?.continueButton.isBusy = false
                        }
                    })
                } else if error.code == NSURLErrorNotConnectedToInternet && weakSelf.isNetworkPermissionRestricted {
                    weakSelf.alertSettings(R.string.localizable.permission_denied_network())
                    weakSelf.continueButton.isBusy = false
                } else {
                    if error.status != NSURLErrorTimedOut {
                        var userInfo = [String: Any]()
                        userInfo["errorCode"] = error.code
                        userInfo["errorDescription"] = error.description
                        if let requestId = weakSelf.request?.response?.allHeaderFields["x-request-id"]  {
                            userInfo["requestId"] = requestId
                        }
                        if let statusCode = weakSelf.request?.response?.statusCode {
                            userInfo["statusCode"] = "\(statusCode)"
                        }
                        userInfo["phone"] = ctx.mobileNumber
                        userInfo["phoneCountryCode"] = ctx.callingCode
                        Reporter.report(error: MixinError.requestLoginVerificationCode(userInfo))
                    }
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.continueButton.isBusy = false
                }
            }
        }
    }
    
}
