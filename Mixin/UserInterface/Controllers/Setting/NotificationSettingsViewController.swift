import UIKit

class NotificationSettingsViewController: UITableViewController {
    
    @IBOutlet weak var messagePreviewSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messagePreviewSwitch.isOn = CommonUserDefault.shared.shouldShowPreviewForMessageNotification
    }
    
    @IBAction func switchMessagePreview(_ sender: Any) {
        CommonUserDefault.shared.shouldShowPreviewForMessageNotification = messagePreviewSwitch.isOn
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "notification")
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_TITLE)
    }
    
}
