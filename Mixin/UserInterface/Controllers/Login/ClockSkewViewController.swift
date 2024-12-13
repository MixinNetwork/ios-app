import UIKit
import MixinServices

final class ClockSkewViewController: UIViewController {
    
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var tipsLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.general.error(category: "ClockSkew", message: "View did load")
    }
    
    @IBAction func continueAction(_ sender: Any) {
        guard !continueButton.isBusy else {
            return
        }
        continueButton.isBusy = true
        AccountAPI.me { [weak self] (result) in
            switch result {
            case let .success(account):
                Logger.general.info(category: "ClockSkew", message: "Clock fixed")
                AppGroupUserDefaults.isClockSkewed = false
                LoginManager.shared.setAccount(account)
                if let parent = self?.parent as? CheckSessionEnvironmentViewController {
                    parent.check(freshAccount: account)
                } else {
                    assertionFailure()
                }
            case .failure(.clockSkewDetected):
                Logger.general.error(category: "ClockSkew", message: "Still skewed")
                if let self {
                    self.continueButton.isBusy = false
                    self.shakeTips()
                }
            case let .failure(error):
                Logger.general.error(category: "ClockSkew", message: "\(error)")
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.continueButton.isBusy = false
            }
        }
    }
    
    private func shakeTips() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0 ]
        tipsLabel.layer.add(animation, forKey: "shake")
    }
    
}
