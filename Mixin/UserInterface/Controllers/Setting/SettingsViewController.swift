import UIKit
import MixinServices

class SettingsViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_security(),
                        title: R.string.localizable.setting_privacy_and_security(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_notification(),
                        title: R.string.localizable.setting_notification(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_backup(),
                        title: R.string.localizable.setting_backup_title(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_storage(),
                        title: R.string.localizable.setting_data_and_storage(),
                        accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_appearance(),
                        title: R.string.localizable.setting_appearance(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_desktop(),
                        title: R.string.localizable.setting_desktop(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_feedback(),
                        title: R.string.localizable.setting_feedback(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_share(),
                        title: R.string.localizable.setting_share_this_app(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_about(),
                        title: R.string.localizable.setting_about(),
                        accessory: .disclosure)
        ])
    ])
    
    class func instance() -> UIViewController {
        let vc = SettingsViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_title())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension SettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                vc = PrivacyViewController.instance()
            case 1:
                vc = NotificationAndConfirmationSettingsViewController.instance()
            case 2:
                if FileManager.default.ubiquityIdentityToken == nil {
                    alert(Localized.SETTING_BACKUP_DISABLE_TIPS)
                    return
                } else {
                    vc = BackupViewController.instance()
                }
            default:
                vc = DataAndStorageSettingsViewController.instance()
            }
        case 1:
            vc = AppearanceSettingsViewController.instance()
        case 2:
            vc = DesktopViewController.instance()
        case 3:
            if indexPath.row == 0 {
                if let user = UserDAO.shared.getUser(identityNumber: "7000") {
                    vc = ConversationViewController.instance(ownerUser: user)
                } else {
                    return
                }
            } else {
                let content = R.string.localizable.setting_share_this_app_content(myIdentityNumber)
                let controller = UIActivityViewController(activityItems: [content], applicationActivities: nil)
                present(controller, animated: true, completion: nil)
                return
            }
        default:
            vc = AboutViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
