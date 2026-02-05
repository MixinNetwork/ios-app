import UIKit
import MixinServices

class DesktopViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [])
    
    private lazy var loginSection = SettingsSection(rows: [
        SettingsRow(title: R.string.localizable.scan_qr_code(),
                    accessory: .disclosure)
    ])
    private lazy var logoutSection = SettingsSection(footer: R.string.localizable.desktop_on_hint(), rows: [
        SettingsRow(title: R.string.localizable.log_out_from_desktop(), titleStyle: .highlighted)
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.mixin_messenger_desktop()
        tableView.tableHeaderView = R.nib.desktopTableHeaderView(withOwner: nil)
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
                loginSection.footer = R.string.localizable.last_active_time(time)
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
        if let sessionID = AppGroupUserDefaults.Account.extensionSession {
            let desktopSession = DesktopSessionValidationViewController(intent: .logout(sessionID: sessionID))
            let authentication = AuthenticationViewController(intent: desktopSession)
            present(authentication, animated: true)
        } else {
            let scanner = QRCodeScannerViewController()
            navigationController?.pushViewController(scanner, animated: true)
        }
    }
    
}
