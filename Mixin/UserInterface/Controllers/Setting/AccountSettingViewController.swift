import UIKit
import MixinServices

final class AccountSettingViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.privacy(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.security(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.change_number(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.delete_my_account(), accessory: .disclosure)
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    class func instance() -> UIViewController {
        let vc = AccountSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.account())
    }
    
}

extension AccountSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewController: UIViewController
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                viewController = PrivacySettingViewController.instance()
            case 1:
                viewController = SecuritySettingViewController.instance()
            default:
                switch TIP.status {
                case .ready, .needsMigrate:
                    let vc = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
                    present(vc, animated: true, completion: nil)
                case .needsInitialize:
                    let tip = TIPNavigationViewController(intent: .create, destination: .changePhone)
                    present(tip, animated: true)
                case .unknown:
                    break
                }
                return
            }
        } else {
            viewController = DeleteAccountSettingViewController.instance()
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}
