import UIKit
import MixinServices

final class AccountSettingViewController: SettingsTableViewController, LogoutHandler {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.privacy(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.security(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.log_out(), titleStyle: .destructive, accessory: .disclosure),
            SettingsRow(title: R.string.localizable.delete_my_account(), titleStyle: .destructive, accessory: .disclosure),
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.account()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension AccountSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewController: UIViewController
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                viewController = PrivacySettingViewController()
            default:
                viewController = SecuritySettingViewController()
            }
        default:
            switch indexPath.row {
            case 0:
                presentLogoutConfirmationAlert()
                return
            default:
                viewController = DeleteAccountSettingViewController()
            }
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}
