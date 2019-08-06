import UIKit

final class PrivacyViewController: UITableViewController {
    
    @IBOutlet weak var blockLabel: UILabel!
    @IBOutlet weak var emergencyLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    
    private let blockedUsersIndexPath = IndexPath(row: 0, section: 0)
    private let footerReuseId = "footer"
    
    private lazy var userWindow = UserWindow.instance()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.privacy()!
        let container = ContainerViewController.instance(viewController: vc, title: Localized.SETTING_PRIVACY_AND_SECURITY)
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SeparatorShadowFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        NotificationCenter.default.addObserver(self, selector: #selector(updateBlockedUserCell), name: .UserDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePasswordCell), name: .AccountDidChange, object: nil)
        updateBlockedUserCell()
        updatePasswordCell()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.selectedBackgroundView = UIView.createSelectedBackgroundView()
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                vc = BlockUserViewController.instance()
            } else {
                vc = ConversationSettingViewController.instance()
            }
        case 1:
            if AccountAPI.shared.account?.has_pin ?? false {
                vc = WalletSettingViewController.instance()
            } else {
                vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            }
        case 2:
            vc = AuthorizationsViewController.instance()
        default:
            if AccountAPI.shared.account?.has_pin ?? false {
                vc = EmergencyContactViewController.instance()
            } else {
                vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        if section == 0 {
            view.text = Localized.SETTING_PRIVACY_AND_SECURITY_SUMMARY
        }
        view.shadowView.hasLowerShadow = section != numberOfSections(in: tableView) - 1
        return view
    }
    
    @objc func updateBlockedUserCell() {
        DispatchQueue.global().async {
            let blocked = UserDAO.shared.getBlockUsers()
            DispatchQueue.main.async { [weak self] in
                self?.blockLabel.text = blocked.count > 0 ? "\(blocked.count)" + Localized.SETTING_BLOCKED_USER_COUNT_SUFFIX : Localized.SETTING_BLOCKED_USER_COUNT_NONE
            }
        }
    }

    @objc func updatePasswordCell() {
        DispatchQueue.main.async { [weak self] in
            self?.passwordLabel.text = AccountAPI.shared.account?.has_pin ?? false ? R.string.localizable.wallet_setting() : R.string.localizable.wallet_pin_title()
        }
    }
    
}
