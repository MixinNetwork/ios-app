import UIKit
import MixinServices

final class ScreenLockSettingViewController: SettingsTableViewController {
    
    static let screenLockTimeoutDidUpdateNotification = Notification.Name("one.mixin.messenger.setting.ScreenLockSettingViewController.screenLockTimeoutDidUpdate")
    
    private let timeoutIntervals: [Double] = [60 * 0, 60 * 1, 60 * 5, 60 * 15, 60 * 60]
    
    private let dataSource = SettingsDataSource(sections: [])
    
    private lazy var biometricSwitchRow = SettingsRow(title: R.string.localizable.setting_screen_lock_enable_biometric_title(biometryType.localizedName),
                                                      accessory: .switch(isOn: AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication))
    
    private lazy var timeoutIntervalRow = SettingsRow(title: R.string.localizable.setting_screen_lock_enable_biometric_timeout(),
                                                      subtitle: Localized.SCREEN_LOCK_TIMEOUT_INTERVAL(AppGroupUserDefaults.User.lockScreenTimeoutInterval),
                                                      accessory: .disclosure)
    
    class func instance() -> UIViewController {
        let vc = ScreenLockSettingViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_screen_lock_title())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var rows = [biometricSwitchRow]
        if AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication {
            rows.append(timeoutIntervalRow)
        }
        let biometricFooter =  R.string.localizable.setting_screen_lock_enable_biometric_tip(biometryType.localizedName)
        let section = SettingsSection(footer: biometricFooter, rows: rows)
        dataSource.insertSection(section, at: 0, animation: .none)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(biometricScreenLockDidChange(_:)),
                                               name: SettingsRow.accessoryDidChangeNotification,
                                               object: biometricSwitchRow)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension ScreenLockSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 1 {
            let alert = UIAlertController(title: nil, message: R.string.localizable.setting_screen_lock_enable_biometric_timeout(), preferredStyle: .actionSheet)
            for interval in timeoutIntervals {
                alert.addAction(UIAlertAction(title: Localized.SCREEN_LOCK_TIMEOUT_INTERVAL(interval), style: .default, handler: { (_) in
                    self.setNewTimeoutInterval(interval)
                }))
            }
            alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
}

extension ScreenLockSettingViewController {
    
    @objc private func biometricScreenLockDidChange(_ notification: Notification) {
        AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication.toggle()
        let needsInsertIntervalRow = AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication
            && dataSource.sections[0].rows.count == 1
        let needsRemoveIntervalRow = !AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication
            && dataSource.sections[0].rows.count == 2
        if needsInsertIntervalRow {
            dataSource.appendRows([timeoutIntervalRow], into: 0, animation: .automatic)
            AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate = Date()
        } else if needsRemoveIntervalRow {
            let indexPath = IndexPath(row: 1, section: 0)
            dataSource.deleteRow(at: indexPath, animation: .automatic)
        }
        NotificationCenter.default.post(name: Self.screenLockTimeoutDidUpdateNotification, object: nil)
    }
    
    private func setNewTimeoutInterval(_ interval: Double) {
        AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate = Date()
        AppGroupUserDefaults.User.lockScreenTimeoutInterval = interval
        timeoutIntervalRow.subtitle = Localized.SCREEN_LOCK_TIMEOUT_INTERVAL(AppGroupUserDefaults.User.lockScreenTimeoutInterval)
        NotificationCenter.default.post(name: Self.screenLockTimeoutDidUpdateNotification, object: nil)
    }
    
}

