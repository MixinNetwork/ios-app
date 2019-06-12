import UIKit

class PrivacyViewController: UITableViewController {

    private lazy var actionSectionFooterView = SeparatorShadowFooterView()

    private let blockedUsersIndexPath = IndexPath(row: 0, section: 0)
    private let footerReuseId = "footer"

    @IBOutlet weak var blockLabel: UILabel!
    @IBOutlet weak var emergencyLabel: UILabel!

    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "privacy") as! PrivacyViewController
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func updateBlockedUserCell() {
        DispatchQueue.global().async {
            let blocked = UserDAO.shared.getBlockUsers()
            DispatchQueue.main.async { [weak self] in
                self?.blockLabel.text = blocked.count > 0 ? "\(blocked.count)" + Localized.SETTING_BLOCKED_USER_COUNT_SUFFIX : Localized.SETTING_BLOCKED_USER_COUNT_NONE
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        var vc: UIViewController!
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                vc = BlockUserViewController.instance()
            } else {
                vc = ConversationSettingViewController.instance()
            }
        case 1:
            vc = AuthorizationsViewController.instance()
        default:
            if CommonUserDefault.shared.isEmergencyTips {
                
            } else {

            }
            return
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        if section == 0 {
            view.text = Localized.SETTING_PRIVACY_AND_SECURITY_SUMMARY
        }
        view.shadowView.hasLowerShadow = section != numberOfSections(in: tableView) - 1
        return view
    }


    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
}
