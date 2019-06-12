import UIKit

class SettingViewController: UIViewController {
    
    enum ReuseId {
        static let cell = "setting"
        static let footer = "footer"
    }
    
    @IBOutlet weak var tableView: UITableView!
    
    private let titles = [
        [Localized.SETTING_PRIVACY_AND_SECURITY,
         Localized.SETTING_NOTIFICATION,
         Localized.SETTING_BACKUP_TITLE,
         R.string.localizable.setting_data_and_storage()],
        [Localized.SETTING_DESKTOP],
        [Localized.SETTING_ABOUT]
    ]
    
    private var numberOfBlockedUsers = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "SettingCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.cell)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        
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
                vc = StorageUsageViewController.instance()
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
    
}
