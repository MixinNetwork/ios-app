import UIKit
import MixinServices

final class AddRecoveryContactViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.enable_emergency_contact(), titleStyle: .highlighted, accessory: .disclosure)
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.emergency_contact()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_titlebar_help(),
            target: self,
            action: #selector(help(_:))
        )
        tableView.tableHeaderView = R.nib.recoveryContactTableHeaderView(withOwner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    @objc private func help(_ sender: Any) {
        UIApplication.shared.openURL(url: .emergencyContact)
    }
    
}

extension AddRecoveryContactViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch TIP.status {
        case .ready, .needsMigrate:
            let introduction = RecoveryContactIntroduction1ViewController()
            navigationController?.pushViewController(introduction, animated: true)
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: .setEmergencyContact)
            navigationController?.present(tip, animated: true)
        case .none:
            break
        }
    }
    
}
