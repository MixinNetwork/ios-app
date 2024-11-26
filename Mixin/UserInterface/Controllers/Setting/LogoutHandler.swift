import UIKit
import MixinServices

protocol LogoutHandler {
    
}

extension LogoutHandler where Self: UIViewController {
    
    func presentLogoutConfirmationAlert() {
        let confirmation = UIAlertController(title: R.string.localizable.logout_confirmation(), message: nil, preferredStyle: .alert)
        confirmation.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        confirmation.addAction(UIAlertAction(title: R.string.localizable.log_out(), style: .destructive) { _ in
            self.logoutAfterMnemonicsBackedUp()
        })
        present(confirmation, animated: true)
    }
    
    private func logoutAfterMnemonicsBackedUp() {
        guard let account = LoginManager.shared.account else {
            return
        }
        if account.isAnonymous, !account.hasSaltExported {
            let warning = BackupMnemonicsWarningViewController(
                navigationController: navigationController,
                cancelTitle: R.string.localizable.cancel()
            )
            present(warning, animated: true)
        } else {
            let logout = LogoutValidationViewController()
            let validation = AuthenticationViewController(intent: logout)
            present(validation, animated: true)
        }
    }
    
}
