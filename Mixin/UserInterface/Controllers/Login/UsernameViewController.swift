import UIKit
import MixinServices

class UsernameViewController: LoginInfoInputViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.navigation_title_enter_name()
        textField.text = makeDefaultUsername()
        editingChangedAction(self)
    }
    
    override func continueAction(_ sender: Any) {
        continueButton.isBusy = true
        AccountAPI.shared.update(fullName: trimmedText) { [weak self] (account) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.continueButton.isBusy = false
            switch account {
            case let .success(account):
                LoginManager.shared.setAccount(account)
                AppDelegate.current.window.rootViewController = makeInitialViewController()
            case let .failure(error):
                Reporter.report(error: error)
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
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
