import UIKit
import WCDBSwift

class BackupViewController: UITableViewController {

    @IBOutlet weak var switchIncludeFiles: UISwitch!
    @IBOutlet weak var switchIncludeVideos: UISwitch!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var backupIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var backupLabel: UILabel!
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "backup")
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_BACKUP_TITLE)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        switchIncludeFiles.isOn = CommonUserDefault.shared.hasBackupFiles
        switchIncludeVideos.isOn = CommonUserDefault.shared.hasBackupVideos

        tableView.tableHeaderView = Bundle.main.loadNibNamed("BackupHeader", owner: nil, options: nil)?.first as? UIView
        NotificationCenter.default.addObserver(self, selector: #selector(backupChanged), name: .BackupDidChange, object: nil)
    }

    @objc func backupChanged() {
        backupIndicatorView.stopAnimating()
        backupIndicatorView.isHidden = true
        backupLabel.text = Localized.SETTING_BACKUP_NOW
        backupLabel.textColor = .systemTint
        tableView.reloadData()
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
            if BackupJobQueue.shared.addJob(job: BackupJob(immediatelyBackup: true)) {
                backupIndicatorView.startAnimating()
                backupIndicatorView.isHidden = false
                backupLabel.text = Localized.SETTING_BACKING
                backupLabel.textColor = .lightGray
            }
        } else if indexPath.section == 1 && indexPath.row == 0 {
            navigationController?.pushViewController(BackupCategoryViewController.instance(), animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            let time = CommonUserDefault.shared.lastBackupTime
            if let size = CommonUserDefault.shared.lastBackupSize, size > 0, time > 0 {
                return Localized.SETTING_BACKUP_LAST(time: DateFormatter.backupFormatter.string(from: Date(timeIntervalSince1970: time)), size: size.sizeRepresentation())
            } else {
                return nil
            }
        case 1:
            return Localized.SETTING_BACKUP_TIPS
        default:
            return nil
        }
    }

}
