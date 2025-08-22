import UIKit
import MixinServices

final class ClockSkewViewController: UIViewController, CheckSessionEnvironmentChild {
    
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var tipsLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.login.error(category: "ClockSkew", message: "View did load")
    }
    
    @IBAction func continueAction(_ sender: Any) {
        guard !continueButton.isBusy else {
            return
        }
        continueButton.isBusy = true
        AccountAPI.me { [weak self] (result) in
            switch result {
            case let .success(account):
                Logger.login.info(category: "ClockSkew", message: "Clock fixed")
                AppGroupUserDefaults.isClockSkewed = false
                LoginManager.shared.setAccount(account)
                self?.checkSessionEnvironmentAgain(freshAccount: account)
            case .failure(.clockSkewDetected):
                Logger.login.error(category: "ClockSkew", message: "Still skewed")
                if let self {
                    self.continueButton.isBusy = false
                    self.tipsLabel.layer.addShakeAnimation()
                }
            case let .failure(error):
                Logger.login.error(category: "ClockSkew", message: "\(error)")
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.continueButton.isBusy = false
            }
        }
    }
    
}
