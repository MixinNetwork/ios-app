import UIKit
import MixinServices

final class SecuritySettingViewController: SettingsTableViewController {

    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.pin(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.emergency_contact(), accessory: .disclosure)
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
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }

    class func instance() -> UIViewController {
        let vc = SecuritySettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.security())
    }
    
}

extension SecuritySettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            if LoginManager.shared.account?.hasPIN ?? false {
                vc = PinSettingsViewController.instance()
            } else {
                vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            }
        case 1:
            if LoginManager.shared.account?.hasPIN ?? false {
                vc = EmergencyContactViewController.instance()
            } else {
                vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            }
        case 2:
            vc = AuthorizationsViewController.instance()
        default:
            vc = LogViewController.instance(category: .all)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
