import UIKit
import MixinServices

final class PhoneNumberLoginVerificationCodeViewController: LoginVerificationCodeViewController {
    
    private let helpButton = UIButton(type: .custom)
    
    private var helpButtonBottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        helpButton.setTitle(R.string.localizable.need_help(), for: .normal)
        helpButton.setTitleColor(R.color.red(), for: .normal)
        helpButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        helpButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        helpButton.addTarget(self, action: #selector(helpAction), for: .touchUpInside)
        helpButton.isHidden = true
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helpButton)
        helpButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        helpButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        helpButtonBottomConstraint = helpButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
        helpButtonBottomConstraint.isActive = true
        resendButton.onCountDownFinished = { [weak helpButton] in
            helpButton?.isHidden = false
        }
        reporter.report(event: .loginSMSVerify)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let deactivation = context.deactivation {
            verificationCodeField.resignFirstResponder()
            let window = DeleteAccountAbortWindow.instance()
            window.render(deactivation: deactivation) { abort in
                if abort {
                    self.navigationController?.popViewController(animated: true)
                } else {
                    self.verificationCodeField.becomeFirstResponder()
                }
            }
            window.presentPopupControllerAnimated()
        }
    }
    
    override func layout(for keyboardFrame: CGRect) {
        super.layout(for: keyboardFrame)
        helpButtonBottomConstraint.constant = -keyboardFrame.height - 28
    }
    
    @objc func helpAction() {
        let context = self.context
        let alert = UIAlertController(title: R.string.localizable.help(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.cant_receive_the_code(), style: .default, handler: { (_) in
            UIApplication.shared.open(.cantReceiveOTP, options: [:], completionHandler: nil)
        }))
        if context.hasEmergencyContact {
            alert.addAction(UIAlertAction(title: R.string.localizable.lost_your_mobile_number(), style: .destructive, handler: { (_) in
                let vc = RecoveryContactIDVerificationViewController(context: context)
                self.navigationController?.pushViewController(vc, animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

extension PhoneNumberLoginVerificationCodeViewController: Captcha.Reporting {
    
    var reportingContent: (event: Reporter.Event, type: String) {
        (event: .loginCAPTCHA, type: "phone_number")
    }
    
}
