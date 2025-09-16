import UIKit
import UserNotifications
import MixinServices

final class NotificationAndConfirmationSettingsViewController: SettingsTableViewController {
    
    private lazy var messagePreviewRow = SettingsRow(title: R.string.localizable.message_preview(),
                                                     accessory: .switch(isOn: showsMessagePreview))
    private lazy var duplicateTransferRow = SettingsRow(title: R.string.localizable.duplicate_transfer_confirmation(),
                                                     accessory: .switch(isOn: duplicateTransferConfirmation))
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(footer: R.string.localizable.notification_message_preview_description(), rows: [
            messagePreviewRow
        ]),
        makeTransferNotificationThresholdSection(),
        makeTransferConfirmationThresholdSection(),
        SettingsSection(footer: R.string.localizable.setting_duplicate_transfer_desc(), rows: [
            duplicateTransferRow
        ])
    ])
    
    private lazy var editorController: AlertEditorController = {
        let controller = AlertEditorController(presentingViewController: self)
        controller.isNumericOnly = true
        return controller
    }()
    
    private var enableNotificationHeaderView: EnableNotificationHeaderView? {
        tableView.tableHeaderView as? EnableNotificationHeaderView
    }
    
    private var showsMessagePreview: Bool {
        AppGroupUserDefaults.User.showMessagePreviewInNotification
    }
    
    private var duplicateTransferConfirmation: Bool {
        AppGroupUserDefaults.User.duplicateTransferConfirmation
    }
    
    private var transferNotificationThreshold: String {
        let threshold = LoginManager.shared.account?.transferNotificationThreshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }
    
    private var transferConfirmationThreshold: String {
        let threshold = LoginManager.shared.account?.transferConfirmationThreshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.settings()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(switchMessagePreview(_:)),
            name: SettingsRow.accessoryDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadEnableNotificationView),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        reloadEnableNotificationView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enableNotificationHeaderView?.sizeToFit(tableView: tableView)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            enableNotificationHeaderView?.sizeToFit(tableView: tableView)
        }
    }
    
    @objc func switchMessagePreview(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard case let .switch(isOn, _) = row.accessory else {
            return
        }
        if row == messagePreviewRow {
            AppGroupUserDefaults.User.showMessagePreviewInNotification = isOn
        } else if row == duplicateTransferRow {
            AppGroupUserDefaults.User.duplicateTransferConfirmation = isOn
        }
    }
    
    @objc private func reloadEnableNotificationView() {
        NotificationManager.shared.getAuthorized { [weak self] isAuthorized in
            guard let self else {
                return
            }
            if isAuthorized {
                self.tableView.tableHeaderView = nil
            } else if self.tableView.tableHeaderView == nil {
                let headerView = R.nib.enableNotificationHeaderView(withOwner: nil)!
                headerView.enableNotificationButton.addTarget(
                    self,
                    action: #selector(enablePushNotifications(_:)),
                    for: .touchUpInside
                )
                self.tableView.tableHeaderView = headerView
            }
        }
    }
    
}

extension NotificationAndConfirmationSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let actionTitle = R.string.localizable.change()
        let placeholder = R.string.localizable.amount()
        switch indexPath.section {
        case 1:
            let title = R.string.localizable.transfer_amount_count_down(Currency.current.symbol)
            editorController.present(title: title, actionTitle: actionTitle, currentText: transferNotificationThreshold, placeholder: placeholder) { (controller) in
                guard let amount = controller.textFields?.first?.text else {
                    return
                }
                self.saveTransferNotificationThreshold(amount)
            }
        case 2:
            let title = R.string.localizable.large_amount_confirmation_with_symbol(Currency.current.symbol)
            editorController.present(title: title, actionTitle: actionTitle, currentText: transferConfirmationThreshold, placeholder: placeholder) { (controller) in
                guard let amount = controller.textFields?.first?.text else {
                    return
                }
                self.saveTransferConfirmationThreshold(amount)
            }
        default:
            break
        }
    }
    
}

extension NotificationAndConfirmationSettingsViewController {
    
    @objc private func enablePushNotifications(_ sender: Any) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    NotificationManager.shared.requestAuthorization()
                case .denied:
                    UIApplication.shared.openNotificationSettings()
                case .authorized, .provisional, .ephemeral:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func makeTransferNotificationThresholdSection() -> SettingsSection {
        let representation = Currency.current.symbol + transferNotificationThreshold
        let footer = R.string.localizable.setting_notification_transfer_summary(representation)
        let row = SettingsRow(title: R.string.localizable.transfer_notifications(),
                              subtitle: representation,
                              accessory: .disclosure)
        return SettingsSection(footer: footer, rows: [row])
    }
    
    private func makeTransferConfirmationThresholdSection() -> SettingsSection {
        let representation = Currency.current.symbol + transferConfirmationThreshold
        let footer: String
        if transferConfirmationThreshold == "0" {
            footer = R.string.localizable.setting_transfer_large_summary_greater(representation)
        } else {
            footer = R.string.localizable.setting_transfer_large_summary(representation)
        }
        let row = SettingsRow(title: R.string.localizable.large_amount_confirmation(),
                              subtitle: representation,
                              accessory: .disclosure)
        return SettingsSection(footer: footer, rows: [row])
    }
    
    private func saveTransferNotificationThreshold(_ value: String) {
        guard !value.isEmpty, value.isNumeric else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let request = UserPreferenceRequest(fiat_currency: Currency.current.code,
                                            transfer_notification_threshold: value.doubleValue)
        AccountAPI.preferences(preferenceRequest: request, completion: { (result) in
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                Currency.refreshCurrentCurrency()
                hud.set(style: .notification, text: R.string.localizable.saved())
                let section = self.makeTransferNotificationThresholdSection()
                self.dataSource.replaceSection(at: 1, with: section, animation: .none)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }
    
    private func saveTransferConfirmationThreshold(_ value: String) {
        guard !value.isEmpty, value.isNumeric else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let request = UserPreferenceRequest(fiat_currency: Currency.current.code,
                                            transfer_confirmation_threshold: value.doubleValue)
        AccountAPI.preferences(preferenceRequest: request, completion: { (result) in
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                Currency.refreshCurrentCurrency()
                hud.set(style: .notification, text: R.string.localizable.saved())
                let section = self.makeTransferConfirmationThresholdSection()
                self.dataSource.replaceSection(at: 2, with: section, animation: .none)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }
    
}
