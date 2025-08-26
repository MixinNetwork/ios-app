import UIKit
import MixinServices

final class UsernameViewController: LoginInfoInputViewController, CheckSessionEnvironmentChild {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        titleLabel.text = R.string.localizable.whats_your_name()
        textField.text = makeDefaultUsername()
        editingChangedAction(self)
        reporter.report(event: .signUpFullname)
    }
    
    override func continueToNext(_ sender: Any) {
        continueButton.isBusy = true
        AccountAPI.update(fullName: trimmedText) { [weak self] (account) in
            self?.continueButton.isBusy = false
            switch account {
            case let .success(account):
                LoginManager.shared.setAccount(account)
                self?.checkSessionEnvironmentAgain(freshAccount: account)
            case let .failure(error):
                Logger.login.error(category: "Set Username", message: "Failed: \(error)")
                reporter.report(error: error)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "username"])
    }
    
    private func makeDefaultUsername() -> String? {
        let name = UIDevice.current.name
        let deviceName: String
        if name.range(of: "iPhone") != nil {
            deviceName = "iPhone"
        } else if name.range(of: "iPad") != nil {
            deviceName = "iPad"
        } else if name.range(of: "iPod") != nil {
            deviceName = "iPod"
        } else {
            return nil
        }
        let deviceNamePatterns = [String(format: "'s %@", deviceName),
                                  String(format: "’s %@", deviceName),
                                  String(format: "′s %@", deviceName),
                                  String(format: "的 %@", deviceName),
                                  String(format: "の%@", deviceName),
                                  String(format: "%@ of ", deviceName),
                                  String(format: "%@ de ", deviceName)]
        let forbiddenNames = ["administrator"]
        for deviceNamePattern in deviceNamePatterns {
            if name.contains(deviceNamePattern), let defaultUsername = name.components(separatedBy: deviceNamePattern).first {
                for forbiddenName in forbiddenNames {
                    if defaultUsername.lowercased().contains(forbiddenName) {
                        return nil
                    }
                }
                return defaultUsername
            }
        }
        return nil
    }
    
}
