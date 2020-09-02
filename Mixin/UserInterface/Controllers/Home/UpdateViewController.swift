import UIKit
import MixinServices

class UpdateViewController: UIViewController {

    @IBOutlet weak var tipsLabel: UILabel!

    class func instance() -> UpdateViewController {
        return R.storyboard.home.update()!
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tipsLabel.text = R.string.localizable.app_update_tips(Bundle.main.shortVersion)
        Logger.write(log: "UpdateViewController...")
    }

    @IBAction func continueAction(_ sender: Any) {
        UIApplication.shared.openURL(url: "itms-apps://itunes.apple.com/us/app/id1322324266")
    }

}

