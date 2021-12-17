import UIKit
import MixinServices

class ConfirmationSettingViewController: SettingsTableViewController {

    private lazy var dataSource = SettingsDataSource(sections: [
        makeTransferConfirmationThresholdSection(),
        SettingsSection(footer: R.string.localizable.setting_duplicate_transfer_summary(), rows: [
            SettingsRow(title: R.string.localizable.setting_duplicate_transfer_title(), accessory: .switch(isOn: duplicateTransferConfirmation))
        ])
    ])
    
    private lazy var editorController: AlertEditorController = {
        let controller = AlertEditorController(presentingViewController: self)
        controller.isNumericOnly = true
        return controller
    }()
        
    private var duplicateTransferConfirmation: Bool {
        AppGroupUserDefaults.User.duplicateTransferConfirmation
    }
    
    private var transferConfirmationThreshold: String {
        let threshold = LoginManager.shared.account?.transfer_confirmation_threshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }

    class func instance() -> UIViewController {
        let vc = ConfirmationSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_security_confirmations())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension ConfirmationSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let actionTitle = R.string.localizable.dialog_button_change()
        let placeholder = R.string.localizable.wallet_send_amount()
        let title = R.string.localizable.setting_transfer_large_title(Currency.current.symbol)
        editorController.present(title: title, actionTitle: actionTitle, currentText: transferConfirmationThreshold, placeholder: placeholder) { (controller) in
            guard let amount = controller.textFields?.first?.text else {
                return
            }
            self.saveTransferConfirmationThreshold(amount)
        }
    }

}

extension ConfirmationSettingViewController {
    
    private func makeTransferConfirmationThresholdSection() -> SettingsSection {
        let representation = Currency.current.symbol + transferConfirmationThreshold
        let footer = R.string.localizable.setting_transfer_large_summary(representation)
        let row = SettingsRow(title: R.string.localizable.setting_transfer_large(),
                              subtitle: representation,
                              accessory: .disclosure)
        return SettingsSection(footer: footer, rows: [row])
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
                self.dataSource.replaceSection(at: 0, with: section, animation: .none)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }

}
