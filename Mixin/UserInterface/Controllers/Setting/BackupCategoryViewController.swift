import UIKit

class BackupCategoryViewController: UITableViewController {

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch indexPath.row {
        case 0:
            cell.accessoryType = CommonUserDefault.shared.backupCategory == .daily ? .checkmark : .none
        case 1:
            cell.accessoryType = CommonUserDefault.shared.backupCategory == .weekly ? .checkmark : .none
        case 2:
            cell.accessoryType = CommonUserDefault.shared.backupCategory == .monthly ? .checkmark : .none
        default:
            cell.accessoryType = CommonUserDefault.shared.backupCategory == .off ? .checkmark : .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            CommonUserDefault.shared.backupCategory = .daily
        case 1:
            CommonUserDefault.shared.backupCategory = .weekly
        case 2:
            CommonUserDefault.shared.backupCategory = .monthly
        default:
            CommonUserDefault.shared.backupCategory = .off
        }
        navigationController?.popViewController(animated: true)
    }

    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "backup_category")
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_BACKUP_AUTO)
    }
    
}
