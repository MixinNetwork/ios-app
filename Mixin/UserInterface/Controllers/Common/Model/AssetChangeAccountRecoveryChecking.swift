import UIKit
import MixinServices

protocol AssetChangeAccountRecoveryChecking {
    var accountRecoverCheckingResponder: UIViewController? { get }
}

extension AssetChangeAccountRecoveryChecking where Self: UIViewController {
    
    var accountRecoverCheckingResponder: UIViewController? {
        self
    }
    
}

extension AssetChangeAccountRecoveryChecking {
    
    func withAccountRecoveryChecked(onNext: @escaping () -> Void) {
        guard
            let account = LoginManager.shared.account,
            let accountRecoverCheckingResponder
        else {
            return
        }
        let enabledOptions = AccountRecoveryOption.enabledOptions(account: account)
        if enabledOptions.isEmpty {
            let context = PopupTip.RecoveryContext(
                intent: .assetChangingConfirmation(onCancel: onNext),
                enabledOptions: enabledOptions
            )
            let popup = PopupTipViewController(tip: .recovery(context))
            accountRecoverCheckingResponder.present(popup, animated: true)
        } else {
            onNext()
        }
    }
    
}
