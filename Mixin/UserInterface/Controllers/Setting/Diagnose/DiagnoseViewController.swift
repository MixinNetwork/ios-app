import UIKit
import MixinServices

class DiagnoseViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(header: R.string.localizable.diagnose_warning_hint(), rows: [
            SettingsRow(title: R.string.localizable.database_access(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Enable WebRTC Log", accessory: .switch(isOn: CallService.shared.isWebRTCLogEnabled)),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.clear_unused_cache(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Expiration Availability", accessory: .none),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Delete Spotlight Index", accessory: .none),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "UTXO", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Web3", accessory: .disclosure),
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
#if DEBUG
        let tipSection = SettingsSection(rows: [
            SettingsRow(title: "TIP", accessory: .disclosure),
        ])
        dataSource.insertSection(tipSection, at: dataSource.sections.count, animation: .none)
#endif
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
                                                             title: R.string.localizable.database_access())
            navigationController?.pushViewController(container, animated: true)
        case (2, 0):
            let container = ContainerViewController.instance(viewController: AttachmentDiagnosticViewController(),
                                                             title: R.string.localizable.clear_unused_cache())
            navigationController?.pushViewController(container, animated: true)
        case (3, 0):
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            ExpiredMessageManager.shared.isQueueAvailable { isAvailable in
                hud.set(style: isAvailable ? .notification : .error, text: "")
                hud.scheduleAutoHidden()
            }
        case (4, 0):
            if SpotlightManager.isAvailable {
                SpotlightManager.shared.deleteAllIndexedItems()
                showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
            } else {
                showAutoHiddenHud(style: .error, text: "Not Available")
            }
        case (5, 0):
            let container = ContainerViewController.instance(viewController: UTXODiagnosticViewController(), title: "UTXO")
            navigationController?.pushViewController(container, animated: true)
        case (6, 0):
            let container = ContainerViewController.instance(viewController: Web3DiagnosticViewController(), title: "Web3")
            navigationController?.pushViewController(container, animated: true)
#if DEBUG
        case (7, 0):
            let container = ContainerViewController.instance(viewController: TIPDiagnosticViewController(), title: "TIP")
            navigationController?.pushViewController(container, animated: true)
#endif
        default:
            break
        }
    }
    
}
