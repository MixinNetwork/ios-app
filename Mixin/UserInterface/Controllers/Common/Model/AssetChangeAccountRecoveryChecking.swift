import UIKit
import MixinServices

protocol AssetChangeAccountRecoveryChecking {
    
}

extension AssetChangeAccountRecoveryChecking where Self: UIViewController {
    
    func withAccountRecoveryChecked(onNext: @escaping () -> Void) {
        guard let account = LoginManager.shared.account else {
            return
        }
        let enabledOptions = AccountRecoveryOption.enabledOptions(account: account)
        if enabledOptions.isEmpty {
            let context = PopupTip.RecoveryContext(
                intent: .assetChangingConfirmation(onCancel: onNext),
                enabledOptions: enabledOptions
            )
            let popup = PopupTipViewController(tip: .recovery(context))
            present(popup, animated: true)
        } else {
            onNext()
        }
    }
    
}
