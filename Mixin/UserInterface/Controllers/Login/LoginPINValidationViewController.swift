import UIKit
import MixinServices

final class LoginPINValidationViewController: FullscreenPINValidationViewController, CheckSessionEnvironmentChild {
    
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
        reporter.report(event: .loginPINVerify, tags: ["type": "pin_verify"])
    }
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        AccountAPI.verify(pin: pin) { [weak self, account] result in
            switch result {
            case .success:
                Logger.login.info(category: "LoginPINValidation", message: "Validated")
                AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                AppGroupUserDefaults.User.loginPINValidated = true
                self?.checkSessionEnvironmentAgain(pin: pin)
            case .failure(.response(.malformedPin)):
                Logger.login.error(category: "LoginPINValidation", message: "malformedPin...hasPIN:\(account.hasPIN)...hasSafe:\(account.hasSafe)")
                AppDelegate.current.mainWindow.rootViewController = LegacyPINViewController()
            case .failure(let error):
                Logger.login.error(category: "LoginPINValidation", message: "Failed: \(error)")
                guard let self else {
                    return
                }
                self.pinField.clear()
                self.isBusy = false
                PINVerificationFailureHandler.handle(error: error) { (description) in
                    self.alert(description)
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
        sheet.addAction(UIAlertAction(title: R.string.localizable.logs(), style: .default, handler: { _ in
            let logs = LogViewController(category: .all)
            let navigationController = GeneralAppearanceNavigationController(rootViewController: logs)
            self.present(navigationController, animated: true)
        }))
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
