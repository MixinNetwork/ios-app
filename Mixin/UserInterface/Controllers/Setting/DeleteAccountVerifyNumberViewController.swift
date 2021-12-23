import UIKit

final class DeleteAccountVerifyNumberViewController: MobileNumberViewController {
    
    private lazy var context = VerifyNumberContext()

    deinit {
        CaptchaManager.shared.clean()
    }
    
    override func layout(for keyboardFrame: CGRect) {
        if keyboardFrame.height > keyboardLayoutGuideHeightConstraint.constant {
            keyboardLayoutGuideHeightConstraint.constant = keyboardFrame.height
        }
        view.layoutIfNeeded()
    }
    
    override func continueAction(_ sender: Any) {
        continueButton.isBusy = true
        context.number = fullNumber(withSpacing: false)
        context.numberRepresentation = fullNumber(withSpacing: true)
        requestVerificationCode(captchaToken: nil)
    }
    
    class func instance() -> UIViewController {
        let vc = DeleteAccountVerifyNumberViewController()
        return ContainerViewController.instance(viewController: vc, title: "")
    }

}

extension DeleteAccountVerifyNumberViewController {
    
    private func requestVerificationCode(captchaToken token: CaptchaToken?) {
        //TODO: ‼️ add new purpose
        AccountAPI.sendCode(to: context.number, captchaToken: token, purpose: .phone) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let verification):
                weakSelf.context.verificationId = verification.id
                let vc = DeleteAccountVerifyCodeViewController.instance(context: weakSelf.context)
                weakSelf.navigationController?.pushViewController(vc, animated: true)
                weakSelf.continueButton.isBusy = false
            case let .failure(error):
                switch error {
                case .requiresCaptcha:
                    CaptchaManager.shared.validate(on: weakSelf) { (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(captchaToken: token)
                        default:
                            self?.continueButton.isBusy = false
                        }
                    }
                default:
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.continueButton.isBusy = false
                }
            }
        }
    }
    
}
