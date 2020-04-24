import UIKit
import MixinServices

class DataAndStorageSettingsViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(footer: R.string.localizable.setting_auto_download_hint(), rows: [
            SettingsRow(title: R.string.localizable.setting_storage_photos(),
                        subtitle: AppGroupUserDefaults.User.autoDownloadPhotos.description,
                        accessory: .disclosure),
            SettingsRow(title: R.string.localizable.setting_storage_videos(),
                        subtitle: AppGroupUserDefaults.User.autoDownloadVideos.description,
                        accessory: .disclosure),
            SettingsRow(title: R.string.localizable.setting_storage_files(),
                        subtitle: AppGroupUserDefaults.User.autoDownloadFiles.description,
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_storage_usage(),
                        accessory: .disclosure)
        ])
    ])
    
    class func instance() -> UIViewController {
        let vc = DataAndStorageSettingsViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_data_and_storage())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension DataAndStorageSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            
            func setAutoDownload(_ value: AutoDownload) {
                switch indexPath.row {
                case 0:
                    AppGroupUserDefaults.User.autoDownloadPhotos = value
                case 1:
                    AppGroupUserDefaults.User.autoDownloadVideos = value
                default:
                    AppGroupUserDefaults.User.autoDownloadFiles = value
                }
                dataSource.row(at: indexPath).subtitle = value.description
            }
            
            let message = dataSource.row(at: indexPath).title
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: R.string.localizable.setting_auto_download_never(), style: .default, handler: { (_) in
                setAutoDownload(.never)
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.setting_auto_download_wifi(), style: .default, handler: { (_) in
                setAutoDownload(.wifi)
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.setting_auto_download_wifi_cellular(), style: .default, handler: { (_) in
                setAutoDownload(.wifiAndCellular)
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            let vc = StorageUsageViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}

fileprivate extension AutoDownload {
    
    var description: String {
        switch self {
        case .never:
            return R.string.localizable.setting_auto_download_never()
        case .wifi:
            return R.string.localizable.setting_auto_download_wifi()
        case .wifiAndCellular:
            return R.string.localizable.setting_auto_download_wifi_cellular()
        }
    }
    
}
