import UIKit
import MixinServices

final class LoginPINValidationViewController: FullscreenPINValidationViewController {
    
    private let account: Account
    
    init(account: Account) {
        self.account = account
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [
            .tintedIcon(
                image: R.image.ic_title_more(),
                target: self,
                action: #selector(presentMoreActions(_:))
            ),
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            ),
        ]
        reporter.report(event: .loginVerifyPIN, tags: ["type": "verify_pin"])
    }
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        Task { [account] in
            do {
                if account.hasSafe {
                    Logger.login.info(category: "LoginPINValidation", message: "Already had safe")
                    try await withCheckedThrowingContinuation { continuation in
                        AccountAPI.verify(pin: pin) { result in
                            switch result {
                            case .success:
                                continuation.resume()
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                } else {
                    try await TIP.registerToSafeIfNeeded(account: account, pin: pin)
                }
                try await TIP.registerDefaultCommonWalletIfNeeded(pin: pin)
                AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                
                // This view appears in the following two scenarios:
                // 1. The user is already signed in, but has not registered Safe or Common Wallet.
                // 2. The user has just signed up or just signed in.
                //
                // Use the value of `loginPINValidated` to determine which scenario is being handled:
                // - For scenario 1, the default tab should be Chat.
                // - For scenario 2, the default tab should be Wallet.
                let isNewLogin = !AppGroupUserDefaults.User.loginPINValidated
                
                AppGroupUserDefaults.User.loginPINValidated = true
                reporter.report(event: .loginEnd)
                await MainActor.run {
                    Logger.login.info(category: "LoginPINValidation", message: "Validated")
                    Logger.redirectLogsToLogin = false
                    AppDelegate.current.mainWindow.rootViewController = HomeContainerViewController(
                        initialTab: isNewLogin ? .wallet : .chat
                    )
                }
            } catch MixinAPIResponseError.malformedPin {
                Logger.login.error(category: "LoginPINValidation", message: "malformedPin...hasPIN:\(account.hasPIN)...hasSafe:\(account.hasSafe)")
                await MainActor.run {
                    AppDelegate.current.mainWindow.rootViewController = LegacyPINViewController()
                }
            } catch {
                Logger.login.error(category: "LoginPINValidation", message: "Failed: \(error)")
                await MainActor.run {
                    self.pinField.clear()
                    self.isBusy = false
                    if let error = error as? MixinAPIError {
                        PINVerificationFailureHandler.handle(error: error) { (description) in
                            self.alert(description)
                        }
                    } else {
                        self.alert(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "login_pin_verify"])
    }
    
    @objc private func presentMoreActions(_ sender: Any) {
        let sheet = UIAlertController(title: R.string.localizable.help(), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.forget_pin(), style: .default, handler: { _ in
            let document = PopupTitledWebViewController(
                title: R.string.localizable.forget_pin(),
                subtitle: R.string.localizable.url_forget_pin(),
                url: .forgetPIN
            )
            self.present(document, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.switch_account(), style: .default, handler: { _ in
            LoginManager.shared.logout(reason: "Switch Account")
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        present(sheet, animated: true)
    }
    
}
