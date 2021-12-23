import UIKit
import MixinServices

class NotificationAndConfirmationSettingsViewController: SettingsTableViewController {
    
    private lazy var messagePreviewRow = SettingsRow(title: R.string.localizable.setting_notification_message_preview(),
                                                     accessory: .switch(isOn: showsMessagePreview))
    private lazy var duplicateTransferRow = SettingsRow(title: R.string.localizable.setting_duplicate_transfer_title(),
                                                     accessory: .switch(isOn: duplicateTransferConfirmation))
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(footer: R.string.localizable.setting_notification_message_preview_description(), rows: [
            messagePreviewRow
        ]),
        makeTransferNotificationThresholdSection(),
        makeTransferConfirmationThresholdSection(),
        SettingsSection(footer: R.string.localizable.setting_duplicate_transfer_summary(), rows: [
            duplicateTransferRow
        ])
    ])
    
    private lazy var editorController: AlertEditorController = {
        let controller = AlertEditorController(presentingViewController: self)
        controller.isNumericOnly = true
        return controller
    }()
    
    private var showsMessagePreview: Bool {
        AppGroupUserDefaults.User.showMessagePreviewInNotification
    }
    
    private var duplicateTransferConfirmation: Bool {
        AppGroupUserDefaults.User.duplicateTransferConfirmation
    }
    
    private var transferNotificationThreshold: String {
        let threshold = LoginManager.shared.account?.transfer_notification_threshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }
    
    private var transferConfirmationThreshold: String {
        let threshold = LoginManager.shared.account?.transfer_confirmation_threshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }
    
    class func instance() -> UIViewController {
        let vc = NotificationAndConfirmationSettingsViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_title())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(switchMessagePreview(_:)),
                                               name: SettingsRow.accessoryDidChangeNotification,
                                               object: nil)
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
    
}

extension NotificationAndConfirmationSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let actionTitle = R.string.localizable.dialog_button_change()
        let placeholder = R.string.localizable.wallet_send_amount()
        switch indexPath.section {
        case 1:
            let title = R.string.localizable.setting_notification_transfer_amount(Currency.current.symbol)
            editorController.present(title: title, actionTitle: actionTitle, currentText: transferNotificationThreshold, placeholder: placeholder) { (controller) in
                guard let amount = controller.textFields?.first?.text else {
                    return
                }
                self.saveTransferNotificationThreshold(amount)
            }
        case 2:
            let title = R.string.localizable.setting_transfer_large_title(Currency.current.symbol)
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
    
    private func makeTransferNotificationThresholdSection() -> SettingsSection {
        let representation = Currency.current.symbol + transferNotificationThreshold
        let footer = R.string.localizable.setting_notification_transfer_summary(representation)
        let row = SettingsRow(title: R.string.localizable.setting_notification_transfer(),
                              subtitle: representation,
                              accessory: .disclosure)
        return SettingsSection(footer: footer, rows: [row])
    }
    
    private func makeTransferConfirmationThresholdSection() -> SettingsSection {
        let representation = Currency.current.symbol + transferConfirmationThreshold
        let footer = R.string.localizable.setting_transfer_large_summary(representation)
        let row = SettingsRow(title: R.string.localizable.setting_transfer_large(),
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
                hud.set(style: .notification, text: R.string.localizable.toast_saved())
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
                hud.set(style: .notification, text: R.string.localizable.toast_saved())
                let section = self.makeTransferConfirmationThresholdSection()
                self.dataSource.replaceSection(at: 2, with: section, animation: .none)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }
    
}
