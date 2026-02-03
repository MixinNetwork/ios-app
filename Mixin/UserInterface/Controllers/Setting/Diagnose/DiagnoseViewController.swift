import UIKit
import MixinServices

class DiagnoseViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(header: R.string.localizable.diagnose_warning_hint(), rows: [
            SettingsRow(title: R.string.localizable.database_access(), accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Enable WebRTC Log", accessory: .switch(isOn: CallService.shared.isWebRTCLogEnabled)),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Scan Attachments", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Expiration Availability", accessory: .none),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Delete Spotlight Index", accessory: .none),
        ]),
        SettingsSection(footer: PushNotificationDiagnostic.global.description, rows: [
            SettingsRow(title: "Repair Push Notification", accessory: .none),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "UTXO", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Web3", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.clear_cache()),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Reset View Badges"),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Reset Tips"),
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.diagnose()
#if DEBUG
        let tipSection = SettingsSection(rows: [
            SettingsRow(title: "TIP", accessory: .disclosure),
        ])
        dataSource.insertSection(tipSection, at: dataSource.sections.count, animation: .none)
#endif
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rtcLogEnabledDidSwitch(_:)),
            name: SettingsRow.accessoryDidChangeNotification,
            object: dataSource.sections[1].rows[0]
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPushNotificationStatus(_:)),
            name: PushNotificationDiagnostic.statusDidUpdateNotification,
            object: nil
        )
    }
    
    @objc private func rtcLogEnabledDidSwitch(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard case let .switch(isOn, _) = row.accessory else {
            return
        }
        CallService.shared.isWebRTCLogEnabled = isOn
    }
    
    @objc private func reloadPushNotificationStatus(_ notification: Notification) {
        dataSource.sections[5].footer = PushNotificationDiagnostic.global.description
    }
    
}

extension DiagnoseViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            navigationController?.pushViewController(DatabaseDiagnosticViewController(), animated: true)
        case (2, 0):
            navigationController?.pushViewController(AttachmentDiagnosticViewController(), animated: true)
        case (3, 0):
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            ExpiredMessageManager.shared.isQueueAvailable { isAvailable in
                hud.set(style: isAvailable ? .notification : .error, text: "")
                hud.scheduleAutoHidden()
            }
        case (4, 0):
            if SpotlightManager.isAvailable {
                SpotlightManager.shared.deleteAllIndexedItems()
                showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
            } else {
                showAutoHiddenHud(style: .error, text: "Not Available")
            }
        case (5, 0):
            NotificationManager.shared.registerForRemoteNotificationsIfAuthorized()
        case (6, 0):
            navigationController?.pushViewController(UTXODiagnosticViewController(), animated: true)
        case (7, 0):
            navigationController?.pushViewController(Web3DiagnosticViewController(), animated: true)
        case (8, 0):
            InscriptionContentSession.sessionConfiguration.urlCache?.removeAllCachedResponses()
            showAutoHiddenHud(style: .notification, text: R.string.localizable.successful())
        case (9, 0):
            BadgeManager.shared.resetAll()
            AppGroupUserDefaults.Wallet.hasViewedSafeWalletTip = false
            AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip = false
            AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip = false
            showAutoHiddenHud(style: .notification, text: R.string.localizable.successful())
        case (10, 0):
            AppGroupUserDefaults.appUpdateTipDismissalDate = nil
            AppGroupUserDefaults.User.backupMnemonicsTipDismissalDate = nil
            AppGroupUserDefaults.notificationTipDismissalDate = nil
            AppGroupUserDefaults.User.recoveryContactTipDismissalDate = nil
            AppGroupUserDefaults.appRatingRequestDate = nil
            AppGroupUserDefaults.User.verifyPhoneTipDismissalDate = nil
            showAutoHiddenHud(style: .notification, text: R.string.localizable.successful())
#if DEBUG
        case (11, 0):
            navigationController?.pushViewController(TIPDiagnosticViewController(), animated: true)
#endif
        default:
            break
        }
    }
    
}
