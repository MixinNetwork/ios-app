#if DEBUG
import UIKit
import MixinServices

class TIPDiagnosticViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(header: "Failure Tests", rows: [
            SettingsRow(title: "Fail Last Sign Once", accessory: .switch(isOn: TIPDiagnostic.failLastSignerOnce, isEnabled: true)),
            SettingsRow(title: "Fail PIN Update Server Once", accessory: .switch(isOn: TIPDiagnostic.failPINUpdateServerSideOnce, isEnabled: true)),
            SettingsRow(title: "Fail PIN Update Client Once", accessory: .switch(isOn: TIPDiagnostic.failPINUpdateClientSideOnce, isEnabled: true)),
            SettingsRow(title: "Fail Watch Once", accessory: .switch(isOn: TIPDiagnostic.failCounterWatchOnce, isEnabled: true)),
            SettingsRow(title: "Crash After PIN Update", accessory: .switch(isOn: TIPDiagnostic.crashAfterUpdatePIN, isEnabled: true)),
            SettingsRow(title: "Invalid Nonce Once", accessory: .switch(isOn: TIPDiagnostic.invalidNonceOnce, isEnabled: true)),
        ]),
        SettingsSection(header: "UI Test", rows: [
            SettingsRow(title: "UI Test On", accessory: .switch(isOn: TIPDiagnostic.uiTestOnly, isEnabled: true)),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Remove TIP Priv", titleStyle: .destructive)
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
            TIPDiagnostic.failPINUpdateServerSideOnce.toggle()
        case dataSource.sections[0].rows[2]:
            TIPDiagnostic.failPINUpdateClientSideOnce.toggle()
        case dataSource.sections[0].rows[3]:
            TIPDiagnostic.failCounterWatchOnce.toggle()
        case dataSource.sections[0].rows[4]:
            TIPDiagnostic.crashAfterUpdatePIN.toggle()
        case dataSource.sections[0].rows[5]:
            TIPDiagnostic.invalidNonceOnce.toggle()
        case dataSource.sections[1].rows[0]:
            TIPDiagnostic.uiTestOnly.toggle()
        default:
            break
        }
    }
    
}

extension TIPDiagnosticViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 2:
            AppGroupKeychain.encryptedTIPPriv = nil
            showAutoHiddenHud(style: .notification, text: "Removed")
        case 3:
            navigationController?.popToRootViewController(animated: true)
        default:
            break
        }
    }
    
}

#endif
