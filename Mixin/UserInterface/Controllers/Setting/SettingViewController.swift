import UIKit
import MixinServices

class SettingViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(footer: nil, rows: [
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
        SettingsSection(footer: nil, rows: [
            SettingsRow(icon: R.image.setting.ic_category_appearance(),
                        title: R.string.localizable.setting_appearance(),
                        accessory: .disclosure)
        ]),
        SettingsSection(footer: nil, rows: [
            SettingsRow(icon: R.image.setting.ic_category_desktop(),
                        title: R.string.localizable.setting_desktop(),
                        accessory: .disclosure)
        ]),
        SettingsSection(footer: nil, rows: [
            SettingsRow(icon: R.image.setting.ic_category_about(),
                        title: R.string.localizable.setting_about(),
                        accessory: .disclosure)
        ])
    ])
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.instantiateInitialViewController()!
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_TITLE)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableView = tableView
        dataSource.tableViewDelegate = self
        tableView.dataSource = dataSource
    }
    
}

extension SettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                vc = PrivacyViewController.instance()
            case 1:
                vc = NotificationSettingsViewController.instance()
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
