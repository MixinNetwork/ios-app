import UIKit
import MixinServices

class UserCenterViewController: SettingsTableViewController, MixinNavigationAnimating {
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(icon: R.image.ic_user_profile(),
                        title: R.string.localizable.profile(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.ic_user_qr_code(),
                        title: R.string.localizable.my_qr_code(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.ic_user_receive_money(),
                        title: R.string.localizable.receive_money(),
                        accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.ic_user_chat(),
                        title: R.string.localizable.new_chat(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.ic_title_contact(),
                        title: R.string.localizable.new_group_chat(),
                        accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.ic_user_add_contact(),
                        title: R.string.localizable.add_contact(),
                        accessory: .disclosure),
            SettingsRow(icon: R.image.ic_user_my_contact(),
                        title: R.string.localizable.my_contacts(),
                        accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(icon: R.image.ic_sticker_setting(),
                        title: R.string.localizable.settings(),
                        accessory: .disclosure),
        ]),
    ])
    
    class func instance() -> UIViewController {
        let vc = UserCenterViewController()
        return ContainerViewController.instance(viewController: vc, title:"")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.userCenterTableHeaderView(owner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        reloadAccount()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadAccount),
                                               name: LoginManager.accountDidChangeNotification,
                                               object: nil)
    }
    
}

extension UserCenterViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller: UIViewController
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                guard let account = LoginManager.shared.account else {
                    return
                }
                let user = UserItem.createUser(from: account)
                controller = ContainerViewController.instance(viewController: UserProfileViewController(user: user),
                                                              title: R.string.localizable.profile())
            case 1:
                showMyQrCode()
                return
            default:
                showMyMoneyReceivingCode()
                return
            }
        case 1:
            switch indexPath.row {
            case 0:
                controller = ContactViewController.instance(showAddContactButton: false)
            default:
                controller = AddMemberViewController.instance()
            }
        case 2:
            switch indexPath.row {
            case 0:
                controller = AddContactViewController.instance()
            default:
                controller = ContactViewController.instance()
            }
        default:
            controller = SettingsViewController.instance()
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
}

extension UserCenterViewController {
    
    @objc private func reloadAccount() {
        guard let account = LoginManager.shared.account, let headerView = tableView.tableHeaderView as? UserCenterTableHeaderView else {
            return
        }
        DispatchQueue.main.async {
            headerView.avatarImageView.setImage(with: account.avatarURL, userId: account.userID, name: account.fullName)
            headerView.nameLabel.text = account.fullName
            headerView.identityNumberLabel.text = R.string.localizable.contact_mixin_id(account.identityNumber)
        }
    }
    
    private func showMyQrCode() {
        guard let account = LoginManager.shared.account else {
            return
        }
        let qrCode = QRCodeViewController(account: account)
        present(qrCode, animated: true)
    }
    
    private func showMyMoneyReceivingCode() {
        guard let account = LoginManager.shared.account else {
            return
        }
        let qrCode = QRCodeViewController(title: R.string.localizable.receive_money(),
                                          content: "mixin://transfer/\(account.userID)",
                                          foregroundColor: .black,
                                          description: R.string.localizable.transfer_qrcode_prompt(),
                                          centerView: .receiveMoney({ $0.setImage(with: account) }))
        present(qrCode, animated: true)
    }
    
}

extension UserCenterViewController: ContainerViewControllerDelegate {
    
    func imageBarLeftButton() -> UIImage? {
        R.image.ic_title_close()
    }
    
}
