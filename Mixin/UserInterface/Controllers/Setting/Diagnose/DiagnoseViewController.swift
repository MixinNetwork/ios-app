import UIKit
import MixinServices

class DiagnoseViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(header: R.string.localizable.diagnose_warning(), rows: [
            SettingsRow(title: R.string.localizable.diagnose_database_access(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Enable WebRTC Log", accessory: .switch(isOn: CallService.shared.isWebRTCLogEnabled)),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.diagnose_attachment(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Clear Http Jobs", accessory: .disclosure),
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(rtcLogEnabledDidSwitch(_:)),
                                               name: SettingsRow.accessoryDidChangeNotification,
                                               object: dataSource.sections[1].rows[0])
    }
    
    @objc func rtcLogEnabledDidSwitch(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard case let .switch(isOn, _) = row.accessory else {
            return
        }
        CallService.shared.isWebRTCLogEnabled = isOn
    }
    
}

extension DiagnoseViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let container = ContainerViewController.instance(viewController: DatabaseDiagnosticViewController(),
                                                             title: R.string.localizable.diagnose_database_access())
            navigationController?.pushViewController(container, animated: true)
        case (2, 0):
            let container = ContainerViewController.instance(viewController: AttachmentDiagnosticViewController(),
                                                             title: R.string.localizable.diagnose_attachment())
            navigationController?.pushViewController(container, animated: true)
        case (3, 0):
            let container = ContainerViewController.instance(viewController: ClearHttpJobsViewController(),
                                                             title: "Clear Http Jobs")
            navigationController?.pushViewController(container, animated: true)
        default:
            break
        }
    }
    
}
