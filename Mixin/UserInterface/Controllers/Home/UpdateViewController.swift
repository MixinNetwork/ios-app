import UIKit
import MixinServices

class UpdateViewController: UIViewController {

    @IBOutlet weak var tipsLabel: UILabel!

    class func instance() -> UpdateViewController {
        return R.storyboard.home.update()!
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tipsLabel.text = R.string.localizable.app_update_tips(Bundle.main.shortVersionString)
        Logger.general.error(category: "UpdateViewController", message: "View did load")
    }

    @IBAction func continueAction(_ sender: Any) {
        UIApplication.shared.openAppStorePage()
    }

}

