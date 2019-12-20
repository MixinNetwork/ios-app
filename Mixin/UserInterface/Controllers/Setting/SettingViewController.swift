import UIKit

class SettingViewController: UIViewController {
    
    enum ReuseId {
        static let footer = "footer"
    }
    
    @IBOutlet weak var tableView: UITableView!
    
    private let titles = [
        [Localized.SETTING_PRIVACY_AND_SECURITY,
         Localized.SETTING_NOTIFICATION,
         Localized.SETTING_BACKUP_TITLE,
         R.string.localizable.setting_data_and_storage()],
        [R.string.localizable.wallet_setting()],
        [Localized.SETTING_DESKTOP],
        [Localized.SETTING_ABOUT]
    ]
    
    private var numberOfBlockedUsers = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.settingCell)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(updateWalletSettingTitle), name: LoginManager.accountDidChangeNotification, object: nil)
        updateWalletSettingTitle()
    }
    
    @objc func updateWalletSettingTitle() {
        DispatchQueue.main.async {
            guard let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? SettingCell else {
                return
            }
            let hasPin = LoginManager.shared.account?.has_pin ?? false
            let title = hasPin ? R.string.localizable.wallet_setting() : R.string.localizable.wallet_pin_title()
            cell.titleLabel.text = title
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
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!
        cell.titleLabel.text = titles[indexPath.section][indexPath.row]
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
                vc = PrivacyViewController.instance()
            case 1:
                vc = NotificationSettingsViewController.instance()
            case 2:
                guard FileManager.default.ubiquityIdentityToken != nil else  {
                    alert(Localized.SETTING_BACKUP_DISABLE_TIPS)
                    return
                }
                vc = BackupViewController.instance()
            default:
                vc = DataStorageUsageViewController.instance()
            }
        case 1:
            if LoginManager.shared.account?.has_pin ?? false {
                vc = WalletSettingViewController.instance()
            } else {
                vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            }
        case 2:
            vc = DesktopViewController.instance()
        default:
            vc = AboutViewController.instance()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer) as! SeparatorShadowFooterView
        view.shadowView.hasLowerShadow = section != numberOfSections(in: tableView) - 1
        return view
    }
    
}
