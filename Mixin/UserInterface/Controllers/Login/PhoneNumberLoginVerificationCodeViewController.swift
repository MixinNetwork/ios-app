import UIKit

class PhoneNumberLoginVerificationCodeViewController: LoginVerificationCodeViewController {
    
    private let helpButton = UIButton(type: .custom)
    
    private var helpButtonBottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        helpButton.setTitle(R.string.localizable.button_title_help(), for: .normal)
        helpButton.setTitleColor(.walletRed, for: .normal)
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
    }
    
    override func layout(for keyboardFrame: CGRect) {
        super.layout(for: keyboardFrame)
        helpButtonBottomConstraint.constant = -keyboardFrame.height - 28
    }
    
    @objc func helpAction() {
        let alert = UIAlertController(title: R.string.localizable.title_help(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.button_title_cant_receive_code(), style: .default, handler: { (_) in
            let url = URL(string: "https://mixinmessenger.zendesk.com/hc/articles/360024114492")!
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }))
        if context.hasEmergencyContact {
            alert.addAction(UIAlertAction(title: R.string.localizable.button_title_phone_number_lost(), style: .destructive, handler: { (_) in
                let vc = EmergencyContactIdVerificationViewController()
                vc.context = self.context
                self.navigationController?.pushViewController(vc, animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}
