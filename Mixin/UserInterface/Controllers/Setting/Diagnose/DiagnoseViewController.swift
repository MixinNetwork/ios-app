import UIKit

class DiagnoseViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(header: R.string.localizable.diagnose_warning(), rows: [
            SettingsRow(title: R.string.localizable.diagnose_database_access(), accessory: .disclosure),
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
        let container = ContainerViewController.instance(viewController: DatabaseDiagnosticViewController(),
                                                         title: R.string.localizable.diagnose_database_access())
        navigationController?.pushViewController(container, animated: true)
    }
    
}
