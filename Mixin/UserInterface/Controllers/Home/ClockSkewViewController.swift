import UIKit
import Bugsnag

class ClockSkewViewController: UIViewController {

    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var tipsLabel: UILabel!
    

    class func instance() -> ClockSkewViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "clock") as! ClockSkewViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.write(log: "ClockSkewViewController...")
    }


    @IBAction func continueAction(_ sender: Any) {
        guard !continueButton.isBusy else {
            return
        }
        continueButton.isBusy = true

        AccountAPI.shared.me { [weak self](result) in

            switch result {
            case .success:
                AppGroupUserDefaults.Account.isClockSkewed = false
                AppDelegate.current.window.rootViewController = makeInitialViewController()
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                self?.continueButton.isBusy = false
            }
        }
    }

    func checkFailed() {
        guard continueButton != nil else {
            return
        }
        continueButton.isBusy = false
        tipsLabel.shake()
    }

}

fileprivate extension UIView {
    
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0 ]
        layer.add(animation, forKey: "shake")
    }
}

