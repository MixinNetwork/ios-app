import UIKit

final class SecuritySettingViewController: SettingsTableViewController {

    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_pin(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_emergency_contact(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_authorizations(), accessory: .disclosure)
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }

    class func instance() -> UIViewController {
        let vc = SecuritySettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_account_security())
    }
    
}

extension SecuritySettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            vc = PinSettingsViewController.instance()
        case 1:
            vc = EmergencyContactViewController.instance()
        default:
            vc = AuthorizationsViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
