import UIKit

class PhoneNumberLoginVerificationCodeViewController: LoginVerificationCodeViewController {
    
    private let helpButton = UIButton(type: .custom)
    
    private var helpButtonBottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        helpButton.setTitle(R.string.localizable.button_title_help(), for: .normal)
        helpButton.setTitleColor(UIColor(displayP3RgbValue: 0xF67070), for: .normal)
        helpButton.addTarget(self, action: #selector(helpAction), for: .touchUpInside)
        helpButton.isHidden = true
        view.addSubview(helpButton)
        helpButton.bottomAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        helpButtonBottomConstraint = helpButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
        helpButtonBottomConstraint.isActive = true
    }
    
    override func layout(for keyboardFrame: CGRect) {
        helpButtonBottomConstraint.constant = keyboardFrame.height
    }
    
    @objc func helpAction() {
        let alert = UIAlertController(title: R.string.localizable.title_help(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.button_title_cant_receive_code(), style: .default, handler: { (_) in
            
        }))
        if context.hasEmergencyContact {
            alert.addAction(UIAlertAction(title: R.string.localizable.button_title_phone_number_lost(), style: .destructive, handler: { (_) in
                let vc = EmergencyContactIdVerificationViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}
