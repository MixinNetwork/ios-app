import UIKit
import MixinServices

class ChatsViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.backup_to_icloud(), accessory: .disclosure),
        ]),
        SettingsSection(footer: R.string.localizable.transfer_to_another_phone_hint(), rows: [
            SettingsRow(title: R.string.localizable.transfer_to_pc(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.transfer_to_another_phone(), accessory: .disclosure),
        ]),
        SettingsSection(footer: R.string.localizable.restore_from_pc_hint(), rows: [
            SettingsRow(title: R.string.localizable.restore_from_pc(), accessory: .disclosure),
        ]),
    ])
    
    class func instance() -> UIViewController {
        let vc = ChatsViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_chats())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension ChatsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            if FileManager.default.ubiquityIdentityToken == nil {
                alert(R.string.localizable.backup_disable_hint())
                return
            } else {
                vc = BackupViewController.instance()
            }
        case 1:
            if indexPath.row == 0 {
                vc = TransferToDesktopViewController.instance()
            } else {
                vc = TransferToPhoneViewController.instance()
            }
        default:
            vc = RestoreFromDesktopViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
