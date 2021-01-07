import UIKit
import MixinServices

class ChangeNumberNewNumberViewController: MobileNumberViewController {
    
    var context: ChangeNumberContext!
    
    deinit {
        CaptchaManager.shared.clean()
    }
    
    override func continueAction(_ sender: Any) {
        continueButton.isBusy = true
        context.newNumber = fullNumber(withSpacing: false)
        context.newNumberRepresentation = fullNumber(withSpacing: true)
        requestVerificationCode(captchaToken: nil)
    }
    
    private func requestVerificationCode(captchaToken token: CaptchaToken?) {
        AccountAPI.sendCode(to: context.newNumber, captchaToken: token, purpose: .phone) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let verification):
                weakSelf.context.verificationId = verification.id
                let vc = ChangeNumberVerificationCodeViewController()
                vc.context = weakSelf.context
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
