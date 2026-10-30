import UIKit
import MixinServices

final class UserCenterViewController: SettingsTableViewController {
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(icon: R.image.setting.category_membership(),
                        title: R.string.localizable.mixin_one(),
                        accessory: .disclosure),
            SettingsRow(icon: referralIconImage,
                        title: R.string.localizable.referral(),
                        accessory: .disclosure),
        ]),
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
    
    private var membershipRow: SettingsRow {
        dataSource.sections[0].rows[0]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = TransparentView()
        tableView.tableHeaderView = R.nib.userCenterTableHeaderView(withOwner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadAccount),
            name: LoginManager.accountDidChangeNotification,
            object: nil
        )
        reloadAccount()
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
                if let membership = LoginManager.shared.account?.membership, let plan = membership.plan {
                    controller = MembershipViewController(plan: plan, expiredAt: membership.expiredAt)
                } else {
                    let buy = MembershipPlansViewController(selectedPlan: nil)
                    present(buy, animated: true)
                    return
                }
            default:
                UIApplication.shared.homeNavigationController?.presentReferralPage()
                BadgeManager.shared.setHasViewed(identifier: .referral)
                return
            }
        case 1:
            switch indexPath.row {
            case 0:
                guard let account = LoginManager.shared.account else {
                    return
                }
                let user = UserItem.createUser(from: account)
                controller = UserProfileViewController(user: user)
            case 1:
                showMyQrCode()
                return
            default:
                showMyMoneyReceivingCode()
                return
            }
        case 2:
            switch indexPath.row {
            case 0:
                controller = ContactsViewController(showAddContactButton: false)
            default:
                controller = AddMemberViewController.instance()
            }
        case 3:
            switch indexPath.row {
            case 0:
                controller = AddContactViewController()
            default:
                controller = ContactsViewController(showAddContactButton: true)
            }
        default:
            controller = SettingsViewController()
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
}

extension UserCenterViewController {
    
    @objc private func reloadAccount() {
        guard let account = LoginManager.shared.account else {
            return
        }
        title = account.fullName
        if let headerView = tableView.tableHeaderView as? UserCenterTableHeaderView {
            headerView.avatarImageView.setImage(with: account.avatarURL, userId: account.userID, name: account.fullName)
            headerView.nameLabel.text = account.fullName
            if let image = account.membership?.badgeImage {
                headerView.membershipImageView.image = image
                headerView.membershipImageView.isHidden = false
                headerView.addMembershipButton(target: self, action: #selector(self.buyMembership(_:)))
            } else {
                headerView.membershipImageView.image = nil
                headerView.membershipImageView.isHidden = true
                headerView.removeMembershipButton()
            }
            headerView.identityNumberLabel.text = R.string.localizable.contact_mixin_id(account.identityNumber)
        }
        if let badge = account.membership?.unexpiredPlan?.mediumBadgeImage {
            membershipRow.subtitle = .icon(badge)
        } else {
            membershipRow.subtitle = if account.membership?.plan == nil {
                .text(R.string.localizable.upgrade_plan())
            } else {
                .text(R.string.localizable.renew_plan())
            }
        }
    }
    
    @objc private func buyMembership(_ sender: Any) {
        guard let plan = LoginManager.shared.account?.membership?.unexpiredPlan else {
            return
        }
        let buyingPlan = SafeMembership.Plan(userMembershipPlan: plan)
        let plans = MembershipPlansViewController(selectedPlan: buyingPlan)
        present(plans, animated: true)
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
        let receiveMoney = ReceiveMoneyViewController(account: account)
        navigationController?.pushViewController(receiveMoney, animated: true)
    }
    
}
