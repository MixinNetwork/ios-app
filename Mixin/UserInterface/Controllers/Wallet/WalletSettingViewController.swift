import UIKit
import LocalAuthentication

class WalletSettingViewController: UITableViewController {

    @IBOutlet weak var payTitleLabel: UILabel!
    @IBOutlet weak var biometricsPaySwitch: UISwitch!
    @IBOutlet weak var pinIntervalLabel: UILabel!
    
    private let biometryType: BiometryType = {
        guard #available(iOS 11.0, *), !UIDevice.isJailbreak else {
            return .none
        }
        guard AccountAPI.shared.account?.has_pin ?? false else {
            return .none
        }
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .touchID:
                return .touchID
            case .faceID:
                return .faceID
            default:
                return .none
            }
        } else {
            return .none
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if biometryType != .none {
            biometricsPaySwitch.isOn = WalletUserDefault.shared.isBiometricPay
            payTitleLabel.text = Localized.WALLET_ENABLE_BIOMETRIC_PAY_TITLE(biometricType: biometryType.localizedName)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPinIntervalUI()
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
            
            PinTipsView.instance(tips: tips) { [weak self](pin) in
                guard Keychain.shared.storePIN(pin: pin, prompt: prompt) else {
                    self?.biometricsPaySwitch.isOn = false
                    return
                }
                WalletUserDefault.shared.isBiometricPay = true
                self?.tableView.reloadData()
                }.presentPopupControllerAnimated()
        }
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

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0, biometryType != .none {
            return Localized.WALLET_ENABLE_BIOMETRIC_PAY_PROMPT(biometricType: biometryType.localizedName)
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 1 {
            let vc = PinIntervalViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        } else if indexPath.section == 1 {
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0, biometryType == .none {
            return .leastNormalMagnitude
        } else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }

    @IBAction func changePINAction(_ sender: Any) {
        let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1)
        navigationController?.pushViewController(vc, animated: true)
    }

    class func instance() -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "wallet_setting") as! WalletSettingViewController
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_SETTING)
    }
    
}

extension WalletSettingViewController {
    
    enum BiometryType {
        case faceID
        case touchID
        case none
        
        var localizedName: String {
            switch self {
            case .faceID:
                return Localized.WALLET_FACE_ID
            case .touchID:
                return Localized.WALLET_TOUCH_ID
            case .none:
                return ""
            }
        }
    }
    
}
