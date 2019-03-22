import UIKit
import LocalAuthentication

class WalletSettingViewController: UITableViewController {
    
    @IBOutlet weak var payTitleLabel: UILabel!
    @IBOutlet weak var biometricsPaySwitch: UISwitch!
    @IBOutlet weak var pinIntervalLabel: UILabel!

    private let pinIntervals: [Double] = [ 60 * 15, 60 * 30, 60 * 60, 60 * 60 * 2, 60 * 60 * 6, 60 * 60 * 12, 60 * 60 * 24 ]
    private let footerReuseId = "footer"

    class func instance() -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "wallet_setting") as! WalletSettingViewController
        let container = ContainerViewController.instance(viewController: vc, title: Localized.WALLET_SETTING)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SeparatorShadowFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        if biometryType != .none {
            biometricsPaySwitch.isOn = WalletUserDefault.shared.isBiometricPay
            payTitleLabel.text = Localized.WALLET_ENABLE_BIOMETRIC_PAY_TITLE(biometricType: biometryType.localizedName)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPinIntervalUI()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if biometryType == .none {
                return 0
            } else {
                return WalletUserDefault.shared.isBiometricPay ? 2 : 1
            }
        } else {
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        if biometryType == .none {
            return section == 0 ? nil : view
        } else {
            if section == 0 {
                view.text = Localized.WALLET_ENABLE_BIOMETRIC_PAY_PROMPT(biometricType: biometryType.localizedName)
            }
            return view
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 1 {
            pinIntervalAction()
        } else if indexPath.section == 1 {
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

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
        let validator = PinValidationViewController.instance(tips: Localized.WALLET_PIN_PAY_INTERVAL_CONFIRM, onSuccess: { (_) in
            WalletUserDefault.shared.pinInterval = interval
        })
        present(validator, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 && biometryType == .none {
            return 0
        } else {
            return super.tableView(tableView, heightForFooterInSection: section)
        }
    }
    
    @IBAction func changePINAction(_ sender: Any) {
        let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func biometryPaySwitchAction(_ sender: Any) {
        if WalletUserDefault.shared.isBiometricPay {
            let title = Localized.WALLET_DISABLE_BIOMETRIC_PAY(biometricType: biometryType == .touchID ? Localized.WALLET_TOUCH_ID : Localized.WALLET_FACE_ID)
            let alc = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: { [weak self](_) in
                self?.biometricsPaySwitch.setOn(WalletUserDefault.shared.isBiometricPay, animated: true)
            }))
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_DISABLE, style: .default, handler: { [weak self](_) in
                Keychain.shared.clearPIN()
                WalletUserDefault.shared.isBiometricPay = false
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
            let validator = PinValidationViewController.instance(tips: tips, onSuccess: { (pin) in
                guard Keychain.shared.storePIN(pin: pin, prompt: prompt) else {
                    self.biometricsPaySwitch.isOn = false
                    return
                }
                WalletUserDefault.shared.isBiometricPay = true
                self.tableView.reloadData()
            }, onFailed: {
                self.biometricsPaySwitch.isOn = false
            })
            present(validator, animated: true, completion: nil)
        }
    }
    
    private func refreshPinIntervalUI() {
        let pinInterval = WalletUserDefault.shared.pinInterval
        let hour: Double = 60 * 60
        if pinInterval < hour {
            pinIntervalLabel.text = Localized.WALLET_PIN_PAY_INTERVAL_MINUTES(pinInterval).lowercased()
        } else if pinInterval == hour {
            pinIntervalLabel.text = Localized.WALLET_PIN_PAY_INTERVAL_HOUR
        } else {
            pinIntervalLabel.text = Localized.WALLET_PIN_PAY_INTERVAL_HOURS(pinInterval).lowercased()
        }
    }
    
}
