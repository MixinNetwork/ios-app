#if DEBUG
import UIKit
import MixinServices

class TIPDiagnosticViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(header: "Failure Tests", rows: [
            SettingsRow(title: "Fail Last Sign Once", accessory: .switch(isOn: TIPDiagnostic.failLastSignerOnce, isEnabled: true)),
            SettingsRow(title: "Fail PIN Update Once", accessory: .switch(isOn: TIPDiagnostic.failPINUpdateOnce, isEnabled: true)),
            SettingsRow(title: "Fail Watch Once", accessory: .switch(isOn: TIPDiagnostic.failCounterWatchOnce, isEnabled: true)),
        ]),
        SettingsSection(header: "UI Test", rows: [
            SettingsRow(title: "UI Test On", accessory: .switch(isOn: TIPDiagnostic.uiTestOnly, isEnabled: true)),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Back to Home", titleStyle: .destructive)
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(switchDidToggle(_:)),
                                               name: SettingsRow.accessoryDidChangeNotification,
                                               object: nil)
    }
    
    @objc private func switchDidToggle(_ notification: Notification) {
        switch (notification.object as? SettingsRow) {
        case dataSource.sections[0].rows[0]:
            TIPDiagnostic.failLastSignerOnce.toggle()
        case dataSource.sections[0].rows[1]:
            TIPDiagnostic.failPINUpdateOnce.toggle()
        case dataSource.sections[0].rows[2]:
            TIPDiagnostic.failCounterWatchOnce.toggle()
        case dataSource.sections[1].rows[0]:
            TIPDiagnostic.uiTestOnly.toggle()
        default:
            break
        }
    }
    
}

extension TIPDiagnosticViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2, indexPath.row == 0 {
            navigationController?.popToRootViewController(animated: true)
        }
    }
    
}

#endif
