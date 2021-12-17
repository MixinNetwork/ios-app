import UIKit
import MixinServices

class ChatSettingViewController: SettingsTableViewController {
    
    private lazy var dataSource = SettingsDataSource(sections: [
        makeTransferNotificationThresholdSection(),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_backup_title(), accessory: .disclosure),
            //SettingsRow(title: R.string.localizable.setting_restore_title(), accessory: .disclosure)
        ]),
//        SettingsSection(rows: [
//            SettingsRow(title: R.string.localizable.setting_clear_chat_history(), titleStyle: .destructive, accessory: .disclosure)
//        ])
    ])
    
    private lazy var editorController: AlertEditorController = {
        let controller = AlertEditorController(presentingViewController: self)
        controller.isNumericOnly = true
        return controller
    }()

    private var transferNotificationThreshold: String {
        let threshold = LoginManager.shared.account?.transfer_notification_threshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }
    
    class func instance() -> UIViewController {
        let vc = ChatSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_chat_title())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }

}

extension ChatSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            let actionTitle = R.string.localizable.dialog_button_change()
            let placeholder = R.string.localizable.wallet_send_amount()
            let title = R.string.localizable.setting_notification_transfer_amount(Currency.current.symbol)
            editorController.present(title: title, actionTitle: actionTitle, currentText: transferNotificationThreshold, placeholder: placeholder) { (controller) in
                guard let amount = controller.textFields?.first?.text else {
                    return
                }
                self.saveTransferNotificationThreshold(amount)
            }
        case 1:
            if indexPath.row == 0 {
                if FileManager.default.ubiquityIdentityToken == nil {
                    alert(Localized.SETTING_BACKUP_DISABLE_TIPS)
                    return
                } else {
                    let vc = BackupViewController.instance()
                    navigationController?.pushViewController(vc, animated: true)
                }
            }
        default:
            break
        }
    }
    
}

extension ChatSettingViewController {
    
    private func makeTransferNotificationThresholdSection() -> SettingsSection {
        let representation = Currency.current.symbol + transferNotificationThreshold
        let footer = R.string.localizable.setting_notification_transfer_summary(representation)
        let row = SettingsRow(title: R.string.localizable.setting_notification_transfer(),
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
                self.dataSource.replaceSection(at: 0, with: section, animation: .none)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }
    
}
