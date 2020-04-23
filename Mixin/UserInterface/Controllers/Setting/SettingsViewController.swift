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
                vc = DataStorageUsageViewController.instance()
            }
        case 1:
            return
        case 2:
            vc = DesktopViewController.instance()
        default:
            vc = AboutViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
