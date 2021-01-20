import UIKit
import MixinServices

final class PrivacyViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_pin(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.setting_emergency_contact(), accessory: .disclosure)
        ]),
        SettingsSection(footer: R.string.localizable.setting_privacy_and_security_summary(), rows: [
            SettingsRow(title: R.string.localizable.setting_blocked(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.setting_conversation(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_phone_number_title(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.setting_contacts_title(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_authorizations(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_logs(), accessory: .disclosure)
        ])
    ])
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance() -> UIViewController {
        let vc = PrivacyViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_privacy_and_security())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateBlockedUserCell),
                                               name: UserDAO.userDidChangeNotification,
                                               object: nil)
        updateBlockedUserCell()
    }
    
    @objc func updateBlockedUserCell() {
        DispatchQueue.global().async {
            let blocked = UserDAO.shared.getBlockUsers()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                let indexPath = IndexPath(row: 0, section: 1)
                let row = self.dataSource.row(at: indexPath)
                if blocked.count > 0 {
                    row.subtitle = "\(blocked.count)" + R.string.localizable.setting_blocked_user_count_suffix()
                } else {
                    row.subtitle = R.string.localizable.setting_blocked_user_count_none()
                }
            }
        }
    }
    
}

extension PrivacyViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            if LoginManager.shared.account?.has_pin ?? false {
                if indexPath.row == 0 {
                    vc = PinSettingsViewController.instance()
                } else {
                    vc = EmergencyContactViewController.instance()
                }
            } else {
                vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            }
        case 1:
            if indexPath.row == 0 {
                vc = BlockedUsersViewController.instance()
            } else {
                vc = ConversationSettingViewController.instance()
            }
        case 2:
            if indexPath.row == 0 {
                vc = PhoneNumberSettingViewController.instance()
            } else {
                vc = PhoneContactsSettingViewController.instance()
            }
        case 3:
            vc = AuthorizationsViewController.instance()
        default:
            vc = LogViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
