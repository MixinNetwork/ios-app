import UIKit

class SettingViewController: UIViewController {
    
    enum ReuseId {
        static let cell = "setting"
        enum Footer {
            static let titled = "titled"
            static let plain = "plain"
        }
    }
    
    @IBOutlet weak var tableView: UITableView!
    
    private let blockedUsersIndexPath = IndexPath(row: 0, section: 0)
    private let titles = [
        [Localized.SETTING_BLOCKED,
         Localized.SETTING_CONVERSATION],
        [Localized.SETTING_NOTIFICATION,
         Localized.SETTING_BACKUP_TITLE,
         Localized.SETTING_STORAGE_USAGE],
        [Localized.SETTING_AUTHORIZATIONS],
        [Localized.SETTING_ABOUT]
    ]
    
    private var numberOfBlockedUsers = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "SettingCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.cell)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.Footer.plain)
        tableView.register(TitledShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.Footer.titled)
        tableView.dataSource = self
        tableView.delegate = self
        updateBlockedUserCell()
        NotificationCenter.default.addObserver(self, selector: #selector(updateBlockedUserCell), name: .UserDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func updateBlockedUserCell() {
        DispatchQueue.global().async {
            let blocked = UserDAO.shared.getBlockUsers()
            DispatchQueue.main.async {
                self.numberOfBlockedUsers = blocked.count
                self.tableView.reloadRows(at: [self.blockedUsersIndexPath], with: .none)
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateInitialViewController()!
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_TITLE)
    }
    
}

extension SettingViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell, for: indexPath) as! SettingCell
        cell.titleLabel.text = titles[indexPath.section][indexPath.row]
        if indexPath == blockedUsersIndexPath {
            if numberOfBlockedUsers > 0 {
                cell.subtitleLabel.text = String(numberOfBlockedUsers) + Localized.SETTING_BLOCKED_USER_COUNT_SUFFIX
            } else {
                cell.subtitleLabel.text = Localized.SETTING_BLOCKED_USER_COUNT_NONE
            }
            cell.subtitleLabel.isHidden = false
        } else {
            cell.subtitleLabel.isHidden = true
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
}

extension SettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                vc = BlockUserViewController.instance()
            default:
                vc = ConversationSettingViewController.instance()
            }
        case 1:
            switch indexPath.row {
            case 0:
                vc = NotificationSettingsViewController.instance()
            case 1:
                guard FileManager.default.ubiquityIdentityToken != nil else  {
                    alert(Localized.SETTING_BACKUP_DISABLE_TIPS)
                    return
                }
                vc = BackupViewController.instance()
            default:
                vc = StorageUsageViewController.instance()
            }
        case 2:
            vc = AuthorizationsViewController.instance()
        default:
            vc = AboutViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.Footer.titled) as! TitledShadowFooterView
            view.label.text = Localized.SETTING_PRIVACY_AND_SECURITY_SUMMARY
            return view
        } else {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.Footer.plain)!
            return view
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
}
