import UIKit
import WCDBSwift

class BackupViewController: UITableViewController {

    @IBOutlet weak var switchIncludeFiles: UISwitch!
    @IBOutlet weak var switchIncludeVideos: UISwitch!
    @IBOutlet weak var categoryLabel: UILabel!
    

    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "backup")
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_BACKUP_TITLE)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        switchIncludeFiles.isOn = CommonUserDefault.shared.hasBackupFiles
        switchIncludeVideos.isOn = CommonUserDefault.shared.hasBackupVideos

        tableView.tableHeaderView = Bundle.main.loadNibNamed("BackupHeader", owner: nil, options: nil)?.first as? UIView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch CommonUserDefault.shared.backupCategory {
        case .daily:
            categoryLabel.text = Localized.SETTING_BACKUP_DAILY
        case .weekly:
            categoryLabel.text = Localized.SETTING_BACKUP_WEEKLY
        case .monthly:
            categoryLabel.text = Localized.SETTING_BACKUP_MONTHLY
        case .off:
            categoryLabel.text = Localized.SETTING_BACKUP_OFF
        }
    }

    @IBAction func switchIncludeFiles(_ sender: Any) {
        CommonUserDefault.shared.hasBackupFiles = switchIncludeFiles.isOn
    }

    @IBAction func switchIncludeVideos(_ sender: Any) {
        CommonUserDefault.shared.hasBackupVideos = switchIncludeVideos.isOn
    }

}

extension BackupViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 && indexPath.row == 0 {
            BackupJobQueue.shared.addJob(job: BackupJob())
        } else if indexPath.section == 1 && indexPath.row == 0 {
            navigationController?.pushViewController(BackupCategoryViewController.instance(), animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return Localized.SETTING_BACKUP_LAST(time: "Thursday, 3:06 PM", size: "2.4 MB")
        case 1:
            return Localized.SETTING_BACKUP_TIPS
        default:
            return nil
        }
    }

}
