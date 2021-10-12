import UIKit

class DiagnoseViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(header: R.string.localizable.diagnose_warning(), rows: [
            SettingsRow(title: R.string.localizable.diagnose_database_access(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.diagnose_backup_restore(), accessory: .disclosure),
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension DiagnoseViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            let container = ContainerViewController.instance(viewController: DatabaseDiagnosticViewController(),
                                                             title: R.string.localizable.diagnose_database_access())
            navigationController?.pushViewController(container, animated: true)
        case 1:
            let container = ContainerViewController.instance(viewController: iTunesBackupDiagnosticViewController(),
                                                             title: R.string.localizable.diagnose_backup_restore())
            navigationController?.pushViewController(container, animated: true)
        default:
            break
        }
    }
    
}
