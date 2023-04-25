import UIKit
import MixinServices

class RestoreFromCloudViewController: DeviceTransferSettingViewController {
    
    private let section = SettingsRadioSection(rows: [SettingsRow(title: R.string.localizable.restore_chat_history(), titleStyle: .highlighted)])
    
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    private var isQuerying = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.setting.ic_restore_cloud()
        tableHeaderView.label.text = R.string.localizable.restore_chat_history_hint()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    class func instance() -> UIViewController {
        let controller = RestoreFromCloudViewController()
        return ContainerViewController.instance(viewController: controller, title: R.string.localizable.restore_from_icloud())
    }
    
}

extension RestoreFromCloudViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !isQuerying else {
            return
        }
        let databasePath = AppGroupContainer.userDatabaseUrl.path
        let databaseExists = FileManager.default.fileExists(atPath: databasePath)
        if databaseExists {
            isQuerying = true
            section.setAccessory(.busy, forRowAt: indexPath.row)
            DispatchQueue.global().async {
                if let lastMessageCreatedAt = MessageDAO.shared.lastMessageCreatedAt() {
                    let messageCount = MessageDAO.shared.messagesCount()
                    let createdAt = DateFormatter.dateFull.string(from: lastMessageCreatedAt.toUTCDate())
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else {
                            return
                        }
                        self.section.setAccessory(.none, forRowAt: indexPath.row)
                        let title = R.string.localizable.restore_from_icloud_confirmation(messageCount, createdAt)
                        self.alert(title, actionTitle: R.string.localizable.overwrite()) { _ in
                            self.restoreFromCloud()
                        }
                        self.isQuerying = false
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else {
                            return
                        }
                        self.isQuerying = false
                        self.section.setAccessory(.none, forRowAt: indexPath.row)
                        self.restoreFromCloud()
                    }
                }
            }
        } else {
            restoreFromCloud()
        }
    }
    
}

extension RestoreFromCloudViewController {
    
    private func restoreFromCloud() {
        let controller = DeviceTransferProgressViewController(intent: .restoreFromCloud)
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
