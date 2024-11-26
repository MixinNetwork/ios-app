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
    
    class func instance() -> UIViewController {
        let vc = AccountSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.account())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
                viewController = PrivacySettingViewController.instance()
            default:
                viewController = SecuritySettingViewController.instance()
            }
        default:
            switch indexPath.row {
            case 0:
                presentLogoutConfirmationAlert()
                return
            default:
                viewController = DeleteAccountSettingViewController.instance()
            }
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}
