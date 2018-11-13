import UIKit
import Bugsnag

class ClockSkewViewController: UIViewController {

    @IBOutlet weak var continueAction: StateResponsiveButton!

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

        AccountAPI.shared.checkTime { (result) in

            switch result {
            case .success:
                CommonUserDefault.shared.hasClockSkew = false
                AppDelegate.current.window?.rootViewController = makeInitialViewController()
            case .failure:
                break
            }
        }
    }

}
