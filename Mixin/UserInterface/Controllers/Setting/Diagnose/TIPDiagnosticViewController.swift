import UIKit
import MixinServices

class TIPDiagnosticViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
#if DEBUG
        let nodeSection = SettingsSection(rows: [
            SettingsRow(title: "Fail Last Sign", accessory: .switch(isOn: TIPNode.failLastSigner, isEnabled: true))
        ])
        let actionSection = SettingsSection(rows: [
            SettingsRow(title: "Fake Creation", accessory: .switch(isOn: TIPActionViewController.testCreate, isEnabled: true)),
            SettingsRow(title: "Fake Change", accessory: .switch(isOn: TIPActionViewController.testChange, isEnabled: true)),
            SettingsRow(title: "Fake Migrate", accessory: .switch(isOn: TIPActionViewController.testMigrate, isEnabled: true))
        ])
        dataSource.insertSection(nodeSection, at: 0, animation: .none)
        dataSource.insertSection(actionSection, at: 1, animation: .none)
#endif
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(nodeFailureDidToggle(_:)),
                                               name: SettingsRow.accessoryDidChangeNotification,
                                               object: nil)
    }
    
    @objc private func nodeFailureDidToggle(_ notification: Notification) {
#if DEBUG
        switch (notification.object as? SettingsRow) {
        case dataSource.sections[0].rows[0]:
            TIPNode.failLastSigner.toggle()
        case dataSource.sections[1].rows[0]:
            TIPActionViewController.testCreate.toggle()
        case dataSource.sections[1].rows[1]:
            TIPActionViewController.testChange.toggle()
        case dataSource.sections[1].rows[2]:
            TIPActionViewController.testMigrate.toggle()
        default:
            break
        }
#endif
    }
    
}
