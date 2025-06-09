import UIKit
import MixinServices

class DataAndStorageSettingsViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(footer: R.string.localizable.auto_download_hint(), rows: [
            SettingsRow(title: R.string.localizable.photos(),
                        subtitle: AppGroupUserDefaults.User.autoDownloadPhotos.description,
                        accessory: .disclosure),
            SettingsRow(title: R.string.localizable.videos(),
                        subtitle: AppGroupUserDefaults.User.autoDownloadVideos.description,
                        accessory: .disclosure),
            SettingsRow(title: R.string.localizable.files(),
                        subtitle: AppGroupUserDefaults.User.autoDownloadFiles.description,
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.storage_usage(),
                        accessory: .disclosure)
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.data_and_storage_usage()
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
                dataSource.row(at: indexPath).subtitle = .text(value.description)
            }
            
            let message = dataSource.row(at: indexPath).title
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: R.string.localizable.never_auto_download(), style: .default, handler: { (_) in
                setAutoDownload(.never)
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.wifi(), style: .default, handler: { (_) in
                setAutoDownload(.wifi)
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.wifi_and_cellular(), style: .default, handler: { (_) in
                setAutoDownload(.wifiAndCellular)
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
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
            return R.string.localizable.never_auto_download()
        case .wifi:
            return R.string.localizable.wifi()
        case .wifiAndCellular:
            return R.string.localizable.wifi_and_cellular()
        }
    }
    
}
