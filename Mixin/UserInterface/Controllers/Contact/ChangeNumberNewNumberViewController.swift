import UIKit
import MixinServices

class ChangeNumberNewNumberViewController: MobileNumberViewController {
    
    var context: ChangeNumberContext!
    
    deinit {
        ReCaptchaManager.shared.clean()
    }
    
    override func continueAction(_ sender: Any) {
        continueButton.isBusy = true
        context.newNumber = fullNumber(withSpacing: false)
        context.newNumberRepresentation = fullNumber(withSpacing: true)
        requestVerificationCode(reCaptchaToken: nil)
    }
    
    private func requestVerificationCode(reCaptchaToken token: String? = nil) {
        AccountAPI.shared.sendCode(to: context.newNumber, reCaptchaToken: token, purpose: .phone) { [weak self] (result) in
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
                if error.code == 10005 {
                    ReCaptchaManager.shared.validate(onViewController: weakSelf) { (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(reCaptchaToken: token)
                        default:
                            self?.continueButton.isBusy = false
                        }
                    }
                } else {
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.continueButton.isBusy = false
                }
            }
        }
    }
    
}
