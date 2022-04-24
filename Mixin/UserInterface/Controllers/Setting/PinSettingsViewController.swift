import UIKit
import MixinServices

final class PinSettingsViewController: SettingsTableViewController {
    
    private let pinIntervals: [Double] = [60 * 15, 60 * 30, 60 * 60, 60 * 60 * 2, 60 * 60 * 6, 60 * 60 * 12, 60 * 60 * 24]
    private let tableHeaderView = R.nib.pinSettingTableHeaderView(owner: nil)!
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.change_PIN(), accessory: .disclosure)
        ]),
    ])
    
    private lazy var biometricSwitchRow = SettingsRow(title: R.string.localizable.pay_with(biometryType.localizedName),
                                                      accessory: .switch(isOn: AppGroupUserDefaults.Wallet.payWithBiometricAuthentication))
    private lazy var pinIntervalRow = SettingsRow(title: R.string.localizable.pay_with_PIN_interval(),
                                                  accessory: .disclosure)
    
    private var isBiometricPaymentChangingInProgress = false
    
    class func instance() -> UIViewController {
        let vc = PinSettingsViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.piN())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if biometryType != .none {
            let biometricFooter = R.string.localizable.wallet_enable_biometric_pay(biometryType.localizedName)
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
        updateTableHeaderView()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePinIntervalRow()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds.width != tableHeaderView.frame.width {
            updateTableHeaderView()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateTableHeaderView()
        }
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
            let type = biometryType == .touchID ? R.string.localizable.touch_ID() : R.string.localizable.face_ID()
            let title = R.string.localizable.disable_biometric_pay_confirmation(type)
            let alc = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: { (_) in
                self.isBiometricPaymentChangingInProgress = true
                self.biometricSwitchRow.accessory = .switch(isOn: AppGroupUserDefaults.Wallet.payWithBiometricAuthentication)
            }))
            alc.addAction(UIAlertAction(title: R.string.localizable.disable(), style: .default, handler: { (_) in
                Keychain.shared.clearPIN()
                AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = false
                self.isBiometricPaymentChangingInProgress = true
                self.biometricSwitchRow.accessory = .switch(isOn: false)
            }))
            present(alc, animated: true, completion: nil)
        } else {
            let tips: String, prompt: String
            if biometryType == .touchID {
                tips = R.string.localizable.enable_touch_pay_hint()
                prompt = R.string.localizable.enable_pay_confirmation(R.string.localizable.touch_ID())
            } else {
                tips = R.string.localizable.enable_face_pay_hint()
                prompt = R.string.localizable.enable_pay_confirmation(R.string.localizable.face_ID())
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
        if indexPath.section == 0 && indexPath.row == 1 && biometryType != .none {
            let alert = UIAlertController(title: nil, message: R.string.localizable.wallet_pin_pay_interval_tips(), preferredStyle: .actionSheet)
            for interval in pinIntervals {
                alert.addAction(UIAlertAction(title: title(for: interval), style: .default, handler: { (_) in
                    self.setNewPinInterval(interval: interval)
                }))
            }
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else if (indexPath.section == 1 && biometryType != .none) || (indexPath.section == 0 && biometryType == .none) {
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1, dismissTarget: nil)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}

extension PinSettingsViewController {
    
    private func updateTableHeaderView() {
        let sizeToFit = CGSize(width: view.bounds.width, height: UIView.layoutFittingExpandedSize.height)
        let headerHeight = tableHeaderView.sizeThatFits(sizeToFit).height
        tableHeaderView.frame.size = CGSize(width: view.bounds.width, height: headerHeight)
        tableView.tableHeaderView = tableHeaderView
    }
    
    private func setNewPinInterval(interval: Double) {
        let validator = PinValidationViewController(tips: R.string.localizable.protect_setting_security_hint(), onSuccess: { (_) in
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
        pinIntervalRow.subtitle = title(for: expirationInterval)
    }
    
    private func title(for interval: TimeInterval) -> String {
        let hour: Double = 60 * 60
        if interval < hour {
            return R.string.localizable.minute_count(Int(interval / 60))
        } else if interval == hour {
            return R.string.localizable.one_hour()
        } else {
            return R.string.localizable.hour_count(Int(interval / 3600))
        }
    }
    
}
