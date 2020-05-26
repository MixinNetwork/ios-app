import UIKit
import MixinServices

final class PinSettingsViewController: SettingsTableViewController {
    
    private let pinIntervals: [Double] = [60 * 15, 60 * 30, 60 * 60, 60 * 60 * 2, 60 * 60 * 6, 60 * 60 * 12, 60 * 60 * 24]
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.wallet_change_password(), accessory: .disclosure)
        ])
    ])
    
    private lazy var biometricSwitchRow = SettingsRow(title: R.string.localizable.wallet_enable_biometric_pay_title(biometryType.localizedName),
                                                      accessory: .switch(isOn: AppGroupUserDefaults.Wallet.payWithBiometricAuthentication))
    private lazy var pinIntervalRow = SettingsRow(title: R.string.localizable.wallet_pin_pay_interval(),
                                                  accessory: .disclosure)
    
    private var isBiometricPaymentChangingInProgress = false
    
    class func instance() -> UIViewController {
        let vc = PinSettingsViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_pin())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if biometryType != .none {
            let biometricFooter = R.string.localizable.wallet_enable_biometric_pay_prompt(biometryType.localizedName)
            var rows = [biometricSwitchRow]
            if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                rows.append(pinIntervalRow)
            }
            let section = SettingsSection(footer: biometricFooter, rows: rows)
            dataSource.insertSection(section, at: 0, animation: .none)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(biometricPaymentDidChange(_:)),
                                                   name: SettingsRow.accessoryDidChangeNotification,
                                                   object: biometricSwitchRow)
        }
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePinIntervalRow()
    }
    
    @objc func biometricPaymentDidChange(_ notification: Notification) {
        guard !isBiometricPaymentChangingInProgress else {
            let needsInsertIntervalRow = AppGroupUserDefaults.Wallet.payWithBiometricAuthentication
                && dataSource.sections.count == 2
                && dataSource.sections[0].rows.count == 1
            let needsRemoveIntervalRow = !AppGroupUserDefaults.Wallet.payWithBiometricAuthentication
                && dataSource.sections.count == 2
                && dataSource.sections[0].rows.count == 2
            if needsInsertIntervalRow {
                dataSource.appendRows([pinIntervalRow], into: 0, animation: .automatic)
            } else if needsRemoveIntervalRow {
                let indexPath = IndexPath(row: 1, section: 0)
                dataSource.deleteRow(at: indexPath, animation: .automatic)
            }
            isBiometricPaymentChangingInProgress = false
            return
        }
        if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
            let type = biometryType == .touchID ? R.string.localizable.wallet_touch_id() : R.string.localizable.wallet_face_id()
            let title = Localized.WALLET_DISABLE_BIOMETRIC_PAY(biometricType: type)
            let alc = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: { (_) in
                self.isBiometricPaymentChangingInProgress = true
                self.biometricSwitchRow.accessory = .switch(isOn: AppGroupUserDefaults.Wallet.payWithBiometricAuthentication)
            }))
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_DISABLE, style: .default, handler: { (_) in
                Keychain.shared.clearPIN()
                AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = false
                self.isBiometricPaymentChangingInProgress = true
                self.biometricSwitchRow.accessory = .switch(isOn: false)
            }))
            present(alc, animated: true, completion: nil)
        } else {
            let tips: String, prompt: String
            if biometryType == .touchID {
                tips = Localized.WALLET_PIN_TOUCH_ID_PROMPT
                prompt = R.string.localizable.wallet_store_encrypted_pin(R.string.localizable.wallet_touch_id())
            } else {
                tips = Localized.WALLET_PIN_FACE_ID_PROMPT
                prompt = R.string.localizable.wallet_store_encrypted_pin(R.string.localizable.wallet_face_id())
            }
            let validator = PinValidationViewController(tips: tips, onSuccess: { (pin) in
                guard Keychain.shared.storePIN(pin: pin, prompt: prompt) else {
                    self.isBiometricPaymentChangingInProgress = true
                    self.biometricSwitchRow.accessory = .switch(isOn: false)
                    return
                }
                AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = true
                self.isBiometricPaymentChangingInProgress = true
                self.biometricSwitchRow.accessory = .switch(isOn: true)
            }, onFailed: {
                self.isBiometricPaymentChangingInProgress = true
                self.biometricSwitchRow.accessory = .switch(isOn: false)
            })
            present(validator, animated: true, completion: nil)
        }
    }
    
}

extension PinSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && biometryType != .none {
            if indexPath.row == 1 {
                let alert = UIAlertController(title: nil, message: R.string.localizable.wallet_pin_pay_interval_tips(), preferredStyle: .actionSheet)
                for interval in pinIntervals {
                    alert.addAction(UIAlertAction(title: Localized.WALLET_PIN_PAY_INTERVAL(interval), style: .default, handler: { (_) in
                        self.setNewPinInterval(interval: interval)
                    }))
                }
                alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        } else if indexPath.row == 0 {
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1, dismissTarget: nil)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}

extension PinSettingsViewController {
    
    private func setNewPinInterval(interval: Double) {
        let validator = PinValidationViewController(tips: Localized.WALLET_PIN_PAY_INTERVAL_CONFIRM, onSuccess: { (_) in
            AppGroupUserDefaults.Wallet.biometricPaymentExpirationInterval = interval
            self.updatePinIntervalRow()
        })
        present(validator, animated: true, completion: nil)
    }
    
    private func updatePinIntervalRow() {
        guard biometryType != .none else {
            return
        }
        let expirationInterval = AppGroupUserDefaults.Wallet.biometricPaymentExpirationInterval
        let hour: Double = 60 * 60
        if expirationInterval < hour {
            pinIntervalRow.subtitle = Localized.WALLET_PIN_PAY_INTERVAL_MINUTES(expirationInterval).lowercased()
        } else if expirationInterval == hour {
            pinIntervalRow.subtitle = R.string.localizable.wallet_pin_pay_interval_hour()
        } else {
            pinIntervalRow.subtitle = Localized.WALLET_PIN_PAY_INTERVAL_HOURS(expirationInterval).lowercased()
        }
    }
    
}
