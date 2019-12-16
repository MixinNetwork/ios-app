import UIKit

class DataStorageUsageViewController: UITableViewController {
    
    private let footerReuseId = "footer"
    private let titles = [
        [R.string.localizable.setting_storage_photos(),
         R.string.localizable.setting_storage_videos(),
         R.string.localizable.setting_storage_files()],
        [R.string.localizable.setting_storage_usage()]
    ]
    
    class func instance() -> UIViewController {
        let vc = DataStorageUsageViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_data_and_storage())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .secondaryBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = 64
        tableView.estimatedSectionFooterHeight = 10
        tableView.register(R.nib.settingCell)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: footerReuseId)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let title = titles[indexPath.section][indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!
        if indexPath.section == 0 {
            cell.titleLabel.text = title
            switch indexPath.row {
            case 0:
                cell.subtitleLabel.text = CommonUserDefault.shared.autoDownloadPhotos.description
            case 1:
                cell.subtitleLabel.text = CommonUserDefault.shared.autoDownloadVideos.description
            default:
                cell.subtitleLabel.text = CommonUserDefault.shared.autoDownloadFiles.description
            }
            cell.subtitleLabel.isHidden = false
            return cell
        } else {
            cell.titleLabel.text = title
            cell.subtitleLabel.isHidden = true
            return cell
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            func setAutoDownload(_ value: AutoDownload) {
                switch indexPath.row {
                case 0:
                    CommonUserDefault.shared.autoDownloadPhotos = value
                case 1:
                    CommonUserDefault.shared.autoDownloadVideos = value
                default:
                    CommonUserDefault.shared.autoDownloadFiles = value
                }
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            let alert = UIAlertController(title: nil, message: titles[indexPath.section][indexPath.row], preferredStyle: .actionSheet)
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
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        let isAutoDownloadSection = section == 0
        view.shadowView.hasLowerShadow = isAutoDownloadSection
        view.text = isAutoDownloadSection ? R.string.localizable.setting_auto_download_hint() : nil
        return view
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
