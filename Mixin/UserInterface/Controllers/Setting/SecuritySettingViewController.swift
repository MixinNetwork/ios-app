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
            switch TIP.status {
            case .ready, .needsMigrate:
                vc = PinSettingsViewController.instance()
            case .needsInitialize:
                let tip = TIPNavigationViewController(intent: .create, destination: nil)
                present(tip, animated: true)
                return
            case .unknown:
                return
            }
        case 1:
            switch TIP.status {
            case .ready, .needsMigrate:
                vc = EmergencyContactViewController.instance()
            case .needsInitialize:
                let tip = TIPNavigationViewController(intent: .create, destination: nil)
                present(tip, animated: true)
                return
            case .unknown:
                return
            }
        case 2:
            vc = MixinAuthorizationsViewController.instance()
        default:
            vc = LogViewController.instance(category: .all)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
