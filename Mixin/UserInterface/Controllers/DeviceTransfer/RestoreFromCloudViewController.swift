import UIKit

class RestoreFromCloudViewController: DeviceTransferSettingViewController {
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [SettingsRow(title: R.string.localizable.restore_chat_history(), titleStyle: .highlighted)])
    ])
    
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
        let controller = DeviceTransferProgressViewController(intent: .restoreFromCloud)
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
