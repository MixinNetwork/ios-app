import UIKit
import MixinServices

class DesktopViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [])
    
    private lazy var loginSection = SettingsSection(rows: [
        SettingsRow(title: R.string.localizable.scan_qr_code(),
                    accessory: .disclosure)
    ])
    private lazy var logoutSection = SettingsSection(footer: R.string.localizable.setting_desktop_desktop_on(), rows: [
        SettingsRow(title: R.string.localizable.setting_desktop_log_out(),
                    titleStyle: .highlighted)
    ])
    
    private var isLogoutInProgress = false {
        didSet {
            logoutSection.rows[0].accessory = isLogoutInProgress ? .busy : .none
        }
    }
    
    class func instance() -> UIViewController {
        let vc = DesktopViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_desktop())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.desktopTableHeaderView(owner: nil)
        reloadData()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData),
                                               name: ReceiveMessageService.userSessionDidChangeNotification,
                                               object: nil)
    }
    
    @objc func reloadData() {
        if AppGroupUserDefaults.Account.isDesktopLoggedIn {
            dataSource.reloadSections([logoutSection])
        } else {
            if let lastLoginDate = AppGroupUserDefaults.Account.lastDesktopLoginDate {
                let time = formattedString(from: lastLoginDate)
                loginSection.footer = Localized.SETTING_DESKTOP_LAST_ACTIVE(time: time)
            } else {
                loginSection.footer = nil
            }
            dataSource.reloadSections([loginSection])
        }
    }
    
    private func formattedString(from date: Date) -> String {
        let secondsPerWeek: TimeInterval = 7 * 24 * 60 * 60
        let formatter: DateFormatter
        if date.timeIntervalSinceNow < secondsPerWeek {
            formatter = DateFormatter.nameOfTheDayAndTime
        } else {
            formatter = DateFormatter.dateAndTime
        }
        return formatter.string(from: date)
    }
    
}

extension DesktopViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let sessionId = AppGroupUserDefaults.Account.extensionSession {
            guard !isLogoutInProgress else {
                return
            }
            isLogoutInProgress = true
            AccountAPI.logoutSession(sessionId: sessionId) { [weak self](result) in
                guard let self = self else {
                    return
                }
                self.isLogoutInProgress = false
                switch result {
                case .success:
                    self.reloadData()
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        } else {
            let vc = CameraViewController.instance()
            vc.asQrCodeScanner = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}
