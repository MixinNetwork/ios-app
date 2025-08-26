import UIKit
import MixinServices

final class UpdateViewController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.text = R.string.localizable.app_update_tips(Bundle.main.shortVersionString)
        Logger.login.info(category: "UpdateViewController", message: "View did load")
    }
    
    @IBAction func continueAction(_ sender: Any) {
        UIApplication.shared.openAppStorePage()
    }
    
}
