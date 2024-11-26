import UIKit
import MixinServices

protocol MnemonicsBackupChecking {
    
}

extension MnemonicsBackupChecking where Self: UIViewController {
    
    func withMnemonicsBackupChecked(onNext: @escaping () -> Void) {
        guard let account = LoginManager.shared.account else {
            return
        }
        if account.isAnonymous, !account.hasSaltExported {
            let warning = BackupMnemonicsWarningViewController(
                navigationController: navigationController,
                cancelTitle: R.string.localizable.later()
            )
            warning.onCancel = {
                onNext()
            }
            present(warning, animated: true)
        } else {
            onNext()
        }
    }
    
}
