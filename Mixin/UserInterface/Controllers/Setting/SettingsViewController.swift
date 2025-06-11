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
            SettingsRow(icon: R.image.setting.category_membership(),
                        title: R.string.localizable.mixin_one(),
                        accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.ic_category_appearance(),
                        title: R.string.localizable.appearance(),
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
    
    private var membershipRow: SettingsRow {
        dataSource.sections[1].rows[0]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.settings()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        updateMembershipRow()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMembershipRow),
            name: LoginManager.accountDidChangeNotification,
            object: nil
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ConcurrentJobQueue.shared.addJob(job: RefreshAccountJob())
    }
    
    @objc private func updateMembershipRow() {
        let membership = LoginManager.shared.account?.membership
        membershipRow.subtitle = switch membership?.unexpiredPlan {
        case .advance:
                .icon(R.image.membership_advance()!)
        case .elite:
                .icon(R.image.membership_elite()!)
        case .prosperity:
                .icon(UserBadgeIcon.prosperityImage!)
        case nil:
            if membership?.plan == nil {
                .text(R.string.localizable.upgrade_plan())
            } else {
                .text(R.string.localizable.renew_plan())
            }
        }
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
            if let membership = LoginManager.shared.account?.membership, let plan = membership.plan {
                setting = MembershipViewController(plan: plan, expiredAt: membership.expiredAt)
            } else {
                let buy = MembershipPlansViewController(selectedPlan: nil)
                present(buy, animated: true)
                return
            }
        case 2:
            setting = AppearanceSettingsViewController()
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
