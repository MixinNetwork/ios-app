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
        let next = switch indexPath.section {
        case 0:
            PinSettingsViewController()
        case 1:
            RecoveryKitViewController()
        case 2:
            MixinAuthorizationsViewController()
        default:
            LogViewController.instance(category: .all)
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
}
