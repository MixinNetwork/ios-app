import UIKit

class NotificationSettingsViewController: UITableViewController {
    
    @IBOutlet weak var messagePreviewSwitch: UISwitch!
    @IBOutlet weak var thresholdLabel: UILabel!
    

    private let footerReuseId = "footer"

    private var currentCurrency: Currency {
        return Currency.current
    }
    private var currenyThreshold: String {
        let threshold = LoginManager.shared.account?.transfer_notification_threshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }

    private lazy var hud = Hud()
    private lazy var editAmountController: UIAlertController = {

    let vc = UIApplication.currentActivity()!.alertInput(title: R.string.localizable.setting_notification_transfer_amount(currentCurrency.symbol), placeholder: R.string.localizable.wallet_send_amount(), handler: { [weak self](_) in
            self?.saveThresholdAction()
        })
        vc.textFields?.first?.keyboardType = .decimalPad
        vc.textFields?.first?.addTarget(self, action: #selector(alertInputChangedAction(_:)), for: .editingChanged)
        return vc
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SeparatorShadowFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        messagePreviewSwitch.isOn = AppGroupUserDefaults.User.showMessagePreviewInNotification
        updateThresholdLabel()
    }
    
    @IBAction func switchMessagePreview(_ sender: Any) {
        AppGroupUserDefaults.User.showMessagePreviewInNotification = messagePreviewSwitch.isOn
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.notification()!
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_TITLE)
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        if section == 0 {
            view.text = nil
            view.shadowView.hasLowerShadow = true
        } else {
            view.text = R.string.localizable.setting_notification_transfer_summary("\(currentCurrency.symbol)\(currenyThreshold)")
            view.shadowView.hasLowerShadow = false
        }
        return view
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 {
            editAmountController.textFields?.first?.text = currenyThreshold
            UIApplication.currentActivity()?.present(editAmountController, animated: true, completion: nil)
        }
    }

    private func saveThresholdAction() {
        guard let navigationController = navigationController else {
            return
        }
        guard let thresholdText = editAmountController.textFields?.first?.text, !thresholdText.isEmpty, thresholdText.isNumeric else {
            return
        }
        hud.show(style: .busy, text: "", on: navigationController.view)

        AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest(fiat_currency: Currency.current.code, transfer_notification_threshold: thresholdText.doubleValue), completion: { [weak self] (result) in
            switch result {
            case .success(let account):
                LoginManager.shared.account = account
                Currency.refreshCurrentCurrency()
                self?.hud.set(style: .notification, text: R.string.localizable.toast_saved())
                self?.tableView.reloadData()
                self?.updateThresholdLabel()
            case let .failure(error):
                self?.hud.set(style: .error, text: error.localizedDescription)
            }
            self?.hud.scheduleAutoHidden()
        })
    }


    @objc func alertInputChangedAction(_ sender: Any) {
        guard let text = editAmountController.textFields?.first?.text else {
            return
        }
        editAmountController.actions[1].isEnabled = !text.isEmpty && text.isNumeric
    }

    private func updateThresholdLabel() {
        thresholdLabel.text = "\(currentCurrency.symbol)\(currenyThreshold)"
    }
}
