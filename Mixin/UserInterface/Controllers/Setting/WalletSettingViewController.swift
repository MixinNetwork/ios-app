import UIKit
import LocalAuthentication

class WalletSettingViewController: UITableViewController {
    
    @IBOutlet weak var payTitleLabel: UILabel!
    @IBOutlet weak var biometricsPaySwitch: UISwitch!
    @IBOutlet weak var pinIntervalLabel: UILabel!
    @IBOutlet weak var currencySymbolLabel: UILabel!
    @IBOutlet weak var largeAmountConfirmationLabel: UILabel!
    
    private let pinIntervals: [Double] = [ 60 * 15, 60 * 30, 60 * 60, 60 * 60 * 2, 60 * 60 * 6, 60 * 60 * 12, 60 * 60 * 24 ]
    private let footerReuseId = "footer"
    private var currenyThreshold: String {
        let threshold = Account.current?.transfer_confirmation_threshold ?? 0
        return NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .decimal)
    }
    private var currentCurrency: Currency {
        return Currency.current
    }
    private lazy var hud = Hud()
    private lazy var editAmountController: UIAlertController = {

        let vc = UIApplication.currentActivity()!.alertInput(title: R.string.localizable.setting_transfer_large_title(currentCurrency.symbol), placeholder: R.string.localizable.wallet_send_amount(), handler: { [weak self](_) in
            self?.saveThresholdAction()
        })
        vc.textFields?.first?.keyboardType = .decimalPad
        vc.textFields?.first?.addTarget(self, action: #selector(alertInputChangedAction(_:)), for: .editingChanged)
        return vc
    }()

    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.wallet()!
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.wallet_setting())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SeparatorShadowFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        if biometryType != .none {
            biometricsPaySwitch.isOn = AppGroupUserDefaults.Wallet.payWithBiometricAuthentication
            payTitleLabel.text = Localized.WALLET_ENABLE_BIOMETRIC_PAY_TITLE(biometricType: biometryType.localizedName)
        }
        updateLabels()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateLabels),
                                               name: Currency.currentCurrencyDidChangeNotification,
                                               object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPinIntervalUI()
    }
    
    @IBAction func biometryPaySwitchAction(_ sender: Any) {
        if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
            let title = Localized.WALLET_DISABLE_BIOMETRIC_PAY(biometricType: biometryType == .touchID ? Localized.WALLET_TOUCH_ID : Localized.WALLET_FACE_ID)
            let alc = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: { [weak self](_) in
                self?.biometricsPaySwitch.setOn(AppGroupUserDefaults.Wallet.payWithBiometricAuthentication, animated: true)
            }))
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_DISABLE, style: .default, handler: { [weak self](_) in
                Keychain.shared.clearPIN()
                AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = false
                self?.tableView.reloadData()
            }))
            present(alc, animated: true, completion: nil)
        } else {
            let tips: String, prompt: String
            if biometryType == .touchID {
                tips = Localized.WALLET_PIN_TOUCH_ID_PROMPT
                prompt = Localized.WALLET_STORE_ENCRYPTED_PIN(biometricType: Localized.WALLET_TOUCH_ID)
            } else {
                tips = Localized.WALLET_PIN_FACE_ID_PROMPT
                prompt = Localized.WALLET_STORE_ENCRYPTED_PIN(biometricType: Localized.WALLET_FACE_ID)
            }
            let validator = PinValidationViewController(tips: tips, onSuccess: { (pin) in
                guard Keychain.shared.storePIN(pin: pin, prompt: prompt) else {
                    self.biometricsPaySwitch.isOn = false
                    return
                }
                AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = true
                self.tableView.reloadData()
            }, onFailed: {
                self.biometricsPaySwitch.isOn = false
            })
            present(validator, animated: true, completion: nil)
        }
    }
    
}

extension WalletSettingViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if biometryType == .none {
                return 0
            } else {
                return AppGroupUserDefaults.Wallet.payWithBiometricAuthentication ? 2 : 1
            }
        } else {
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        view.shadowView.hasLowerShadow = section != numberOfSections(in: tableView) - 1

        if section == 0 {
            if biometryType == .none {
                return nil
            } else {
                view.text = Localized.WALLET_ENABLE_BIOMETRIC_PAY_PROMPT(biometricType: biometryType.localizedName)
            }
        } else if section == 3 {
            view.text = R.string.localizable.setting_transfer_large_summary("\(currentCurrency.symbol)\(currenyThreshold)")
        }
        return view
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                pinIntervalAction()
            }
        case 1:
            let vc: UIViewController
            if indexPath.row == 0 {
                vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1, dismissTarget: nil)
            } else {
                vc = PINLogViewController.instance()
            }
            navigationController?.pushViewController(vc, animated: true)
        default:
            if (biometryType == .none && indexPath.section == 2) || indexPath.section == 3 {
                editAmountController.textFields?.first?.text = currenyThreshold
                UIApplication.currentActivity()?.present(editAmountController, animated: true, completion: nil)
            } else {
                let vc = CurrencySelectorViewController()
                present(vc, animated: true, completion: nil)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 && biometryType == .none {
            return .leastNormalMagnitude
        } else if section == 2 {
            return 15 // Avoid shadow from being clipped
        } else {
            return super.tableView(tableView, heightForFooterInSection: section)
        }
    }
    
}

extension WalletSettingViewController {
    
    private func pinIntervalAction() {
        let alc = UIAlertController(title: nil, message: Localized.WALLET_PIN_PAY_INTERVAL_TIPS, preferredStyle: .actionSheet)
        for interval in pinIntervals {
            alc.addAction(UIAlertAction(title: Localized.WALLET_PIN_PAY_INTERVAL(interval), style: .default, handler: { [weak self](_) in
                self?.setNewPinInterval(interval: interval)
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alc, animated: true, completion: nil)
    }
    
    private func setNewPinInterval(interval: Double) {
        let validator = PinValidationViewController(tips: Localized.WALLET_PIN_PAY_INTERVAL_CONFIRM, onSuccess: { (_) in
            AppGroupUserDefaults.Wallet.biometricPaymentExpirationInterval = interval
        })
        present(validator, animated: true, completion: nil)
    }
    
    private func refreshPinIntervalUI() {
        let pinInterval = AppGroupUserDefaults.Wallet.biometricPaymentExpirationInterval
        let hour: Double = 60 * 60
        if pinInterval < hour {
            pinIntervalLabel.text = Localized.WALLET_PIN_PAY_INTERVAL_MINUTES(pinInterval).lowercased()
        } else if pinInterval == hour {
            pinIntervalLabel.text = Localized.WALLET_PIN_PAY_INTERVAL_HOUR
        } else {
            pinIntervalLabel.text = Localized.WALLET_PIN_PAY_INTERVAL_HOURS(pinInterval).lowercased()
        }
    }
    
    @objc private func updateLabels() {
        let currency = Currency.current
        currencySymbolLabel.text = currency.code + " (" + currency.symbol + ")"
        largeAmountConfirmationLabel.text = "\(currency.symbol)\(currenyThreshold)"
        tableView.reloadData()
    }

    @objc func alertInputChangedAction(_ sender: Any) {
        guard let text = editAmountController.textFields?.first?.text else {
            return
        }
        editAmountController.actions[1].isEnabled = !text.isEmpty && text.isNumeric
    }

    private func saveThresholdAction() {
        guard let navigationController = navigationController else {
            return
        }
        guard let thresholdText = editAmountController.textFields?.first?.text, !thresholdText.isEmpty, thresholdText.isNumeric else {
            return
        }
        hud.show(style: .busy, text: "", on: navigationController.view)

        AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest.createRequest(fiat_currency: Currency.current.code, transfer_confirmation_threshold: thresholdText.doubleValue), completion: { [weak self] (result) in
            switch result {
            case .success(let account):
                Account.current = account
                Currency.refreshCurrentCurrency()
                self?.hud.set(style: .notification, text: R.string.localizable.toast_saved())
                self?.updateLabels()
            case let .failure(error):
                self?.hud.set(style: .error, text: error.localizedDescription)
            }
            self?.hud.scheduleAutoHidden()
        })
    }
}
