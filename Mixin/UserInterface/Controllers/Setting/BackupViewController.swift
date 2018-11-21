import UIKit
import WCDBSwift

class BackupViewController: UITableViewController {

    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "backup")
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_TITLE)
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.row == 0 {
            BackupJobQueue.shared.addJob(job: BackupJob())
        }
    }
}
