import UIKit
import Bugsnag

class UsernameViewController: ContinueButtonViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var textField: UITextField!
    
    private var username: String {
        return textField.text ?? ""
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if ScreenSize.current == .inch3_5 {
            contentStackView.spacing = 30
        }
        textField.text = defaultUsername()
        textField.becomeFirstResponder()
        updateContinueButtonStatusAction(self)
    }
    
    override func continueAction(_ sender: Any) {
        continueButton.isBusy = true
        AccountAPI.shared.update(fullName: username) { [weak self] (account) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.continueButton.isBusy = false
            switch account {
            case let .success(account):
                AccountAPI.shared.account = account
                DispatchQueue.global().async {
                    UserDAO.shared.updateAccount(account: account)
                }
                AppDelegate.current.window?.rootViewController = makeInitialViewController()
            case let .failure(error):
                Bugsnag.notifyError(error)
                showHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @IBAction func updateContinueButtonStatusAction(_ sender: Any) {
        continueButton.isHidden = username.isEmpty
    }
    
    private func defaultUsername() -> String? {
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
