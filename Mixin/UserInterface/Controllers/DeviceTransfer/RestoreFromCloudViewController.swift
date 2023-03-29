import UIKit

class RestoreFromCloudViewController: DeviceTransferSettingViewController {
    
    private var isUsernameJustInitialized = false
    
    private let restoreActionRow = SettingsRow(title: R.string.localizable.restore_chat_history(), titleStyle: .highlighted)
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [restoreActionRow])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.setting.ic_restore_cloud()
        tableHeaderView.label.text = R.string.localizable.restore_chat_history_hint()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    class func instance(isUsernameJustInitialized: Bool) -> UIViewController {
        let controller = RestoreFromCloudViewController()
        controller.isUsernameJustInitialized = isUsernameJustInitialized
        return ContainerViewController.instance(viewController: controller, title: R.string.localizable.restore_from_icloud())
    }
    
}

extension RestoreFromCloudViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller = DeviceTransferProgressViewController()
        controller.invoker = .restoreFromCloud(isUsernameJustInitialized)
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
