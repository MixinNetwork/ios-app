import UIKit
import MixinServices

final class SecuritySettingViewController: SettingsTableViewController {

    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.pin(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.recovery_kit(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.authorizations(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.logs(), accessory: .disclosure)
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.security()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension SecuritySettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            switch TIP.status {
            case .ready, .needsMigrate:
                vc = PinSettingsViewController()
            case .needsInitialize:
                let tip = TIPNavigationViewController(intent: .create, destination: nil)
                present(tip, animated: true)
                return
            case .none:
                return
            }
        case 1:
            switch TIP.status {
            case .ready, .needsMigrate:
                vc = RecoveryKitViewController()
            case .needsInitialize:
                let tip = TIPNavigationViewController(intent: .create, destination: nil)
                present(tip, animated: true)
                return
            case .none:
                return
            }
        case 2:
            vc = MixinAuthorizationsViewController()
        default:
            vc = LogViewController.instance(category: .all)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
