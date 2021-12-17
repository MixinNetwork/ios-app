import UIKit

class SecuritySettingViewController: SettingsTableViewController {

    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_pin(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_emergency_contact(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_authorizations(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_security_confirmations(), accessory: .disclosure)
        ])
    ])

    class func instance() -> UIViewController {
        let vc = SecuritySettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_account_security())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }

}

extension SecuritySettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            vc = PinSettingsViewController.instance()
        case 1:
            vc = EmergencyContactViewController.instance()
        case 2:
            vc = AuthorizationsViewController.instance()
        default:
            vc = ConfirmationSettingViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
