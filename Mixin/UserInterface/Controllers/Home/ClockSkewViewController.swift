import UIKit
import Bugsnag

class ClockSkewViewController: UIViewController {

    @IBOutlet weak var continueAction: StateResponsiveButton!
    @IBOutlet weak var tipsLabel: UILabel!
    

    class func instance() -> ClockSkewViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "clock") as! ClockSkewViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        FileManager.default.writeLog(log: "ClockSkewViewController...")
    }


    @IBAction func continueAction(_ sender: Any) {
        guard !continueAction.isBusy else {
            return
        }
        continueAction.isBusy = true

        AccountAPI.shared.me { [weak self](result) in

            switch result {
            case .success:
                AccountUserDefault.shared.hasClockSkew = false
                AppDelegate.current.window?.rootViewController = makeInitialViewController()
            case .failure:
                self?.continueAction.isBusy = false
            }
        }
    }

    func checkFailed() {
        continueAction.isBusy = false
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

