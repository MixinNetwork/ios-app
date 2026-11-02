import UIKit
import MixinServices

final class DiagnoseViewController: SettingsTableViewController {
    
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
        SettingsSection(rows: [
            SettingsRow(title: "Inspect WebView", accessory: .switch(isOn: DiagnoseSwitches.isWebViewInspectable)),
            SettingsRow(
                title: "Bot Signing Slacken",
                accessory: .switch(isOn: !DiagnoseSwitches.botSigningWhitelist.isEmpty)
            ),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Reset Perps Orders"),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Membership", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Delete Markets"),
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
            selector: #selector(webViewInspectableDidSwitch(_:)),
            name: SettingsRow.accessoryDidChangeNotification,
            object: dataSource.sections[11].rows[0]
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(signingForTestBotsDidSwitch(_:)),
            name: SettingsRow.accessoryDidChangeNotification,
            object: dataSource.sections[11].rows[1]
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
    
    @objc private func webViewInspectableDidSwitch(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard case let .switch(isOn, _) = row.accessory else {
            return
        }
        DiagnoseSwitches.isWebViewInspectable = isOn
    }
    
    @objc private func signingForTestBotsDidSwitch(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard case let .switch(isOn, _) = row.accessory else {
            return
        }
        DiagnoseSwitches.botSigningWhitelist = if isOn {
            [
                "39312e2f-5e4a-4eae-94cd-355f38341be3",
                "04379bf8-87fb-41c6-a247-ee19bf9cf4a3",
                "3bdefc26-28fc-4e7c-8848-67272ff95879",
                "b26b9a74-40dd-4e8d-8e41-94d9fce0b5c0",
                "7766b24c-1a03-4c3a-83a3-b4358266875d",
                "47694216-9714-495b-9992-034c8ce91a50",
            ]
        } else {
            []
        }
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
        case (1, 0):
            // Enable WebRTC Log
            break
        case (2, 0):
            navigationController?.pushViewController(AttachmentDiagnosticViewController(), animated: true)
        case (3, 0):
            let hud = Hud()
            hud.show(style: .busy, text: "")
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
            AppGroupUserDefaults.Wallet.hasViewedSafeWalletIntroduction = false
            AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletIntroduction = false
            AppGroupUserDefaults.Wallet.hasViewedClassicWalletIntroduction = false
            AppGroupUserDefaults.Wallet.perpsOpenPositionTakeProfitDismissalDate = .distantPast
            AppGroupUserDefaults.Wallet.perpsOpenPositionStopLossDismissalDate = .distantPast
            showAutoHiddenHud(style: .notification, text: R.string.localizable.successful())
        case (10, 0):
            AppGroupUserDefaults.appUpdateTipDismissalDate = nil
            AppGroupUserDefaults.User.recoveryKitTipDismissalDate = nil
            AppGroupUserDefaults.notificationTipDismissalDate = nil
            AppGroupUserDefaults.appRatingRequestDate = nil
            AppGroupUserDefaults.User.verifyPhoneTipDismissalDate = nil
            AppGroupUserDefaults.Wallet.closedBannerIDs = []
            showAutoHiddenHud(style: .notification, text: R.string.localizable.successful())
        case (11, _):
            // Inspect WebView or Sign Bot
            break
        case (12, 0):
            PerpsOrderDAO.shared.deleteAll()
            showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
        case (13, 0):
            navigationController?.pushViewController(MembershipDiagnoseViewController(), animated: true)
        case (14, 0):
            MarketDAO.shared.deleteAll()
            PerpsMarketDAO.shared.deleteAll()
            PropertiesDAO.shared.removeValue(forKey: .globalMarket)
            showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
#if DEBUG
        default:
            navigationController?.pushViewController(TIPDiagnosticViewController(), animated: true)
#else
        default:
            break
#endif
        }
    }
    
}
