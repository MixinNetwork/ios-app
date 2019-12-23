import UIKit
import MixinServices

final class PrivacyViewController: UITableViewController {
    
    @IBOutlet weak var blockLabel: UILabel!
    @IBOutlet weak var emergencyLabel: UILabel!
    
    private let blockedUsersIndexPath = IndexPath(row: 0, section: 0)
    private let footerReuseId = "footer"
    
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
        updateBlockedUserCell()
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
            vc = AuthorizationsViewController.instance()
        case 2:
            if LoginManager.shared.account?.has_pin ?? false {
                vc = EmergencyContactViewController.instance()
            } else {
                vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            }
        default:
            vc = ContactSettingViewController.instance()
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
    
}
