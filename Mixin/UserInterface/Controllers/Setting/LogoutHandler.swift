import UIKit
import MixinServices

protocol LogoutHandler {
    
}

extension LogoutHandler where Self: UIViewController {
    
    func presentLogoutConfirmationAlert() {
        let confirmation = UIAlertController(title: R.string.localizable.logout_confirmation(), message: nil, preferredStyle: .alert)
        confirmation.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        confirmation.addAction(UIAlertAction(title: R.string.localizable.log_out(), style: .destructive) { _ in
            self.logoutAfterRecoverableConfirmed()
        })
        present(confirmation, animated: true)
    }
    
    private func logoutAfterRecoverableConfirmed() {
        guard let account = LoginManager.shared.account else {
            return
        }
        let enabledOptions = AccountRecoveryOption.enabledOptions(account: account)
        if enabledOptions.isEmpty {
            let context = PopupTip.RecoveryContext(
                intent: .logoutConfirmation,
                enabledOptions: enabledOptions
            )
            let popup = PopupTipViewController(tip: .recovery(context))
            present(popup, animated: true)
        } else {
            let logout = LogoutValidationViewController()
            let validation = AuthenticationViewController(intent: logout)
            present(validation, animated: true)
        }
    }
    
}
