import UIKit
import MixinServices

final class SettingsViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_account(),
                        title: R.string.localizable.account(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_chats(),
                        title: R.string.localizable.setting_chats(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_notification(),
                        title: R.string.localizable.notification_and_confirmation(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_storage(),
                        title: R.string.localizable.data_and_storage_usage(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_appearance(),
                        title: R.string.localizable.appearance(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.category_membership(),
                        title: "Mixin One",
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_desktop(),
                        title: R.string.localizable.mixin_messenger_desktop(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_feedback(),
                        title: R.string.localizable.feedback(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.setting.ic_category_share(),
                        title: R.string.localizable.invite_a_friend(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_about(),
                        title: R.string.localizable.about(),
                        accessory: .disclosure)
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.settings()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension SettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let setting: UIViewController
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                setting = AccountSettingViewController()
            case 1:
                setting = ChatsViewController()
            case 2:
                setting = NotificationAndConfirmationSettingsViewController()
            default:
                setting = DataAndStorageSettingsViewController()
            }
        case 1:
            setting = AppearanceSettingsViewController()
        case 2:
            if let account = LoginManager.shared.account {
                setting = MembershipViewController(account: account)
            } else {
                return
            }
        case 3:
            setting = DesktopViewController()
        case 4:
            if indexPath.row == 0 {
                if let user = UserDAO.shared.getUser(identityNumber: "7000") {
                    setting = ConversationViewController.instance(ownerUser: user)
                } else {
                    return
                }
            } else {
                let content = R.string.localizable.chat_on_mixin_content(myIdentityNumber)
                let controller = UIActivityViewController(activityItems: [content], applicationActivities: nil)
                present(controller, animated: true, completion: nil)
                return
            }
        default:
            setting = AboutViewController()
        }
        navigationController?.pushViewController(setting, animated: true)
    }
    
}
