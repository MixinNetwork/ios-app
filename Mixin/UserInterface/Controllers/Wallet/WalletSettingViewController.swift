import UIKit
import LocalAuthentication

@available(iOS 11.0, *)
class WalletSettingViewController: UITableViewController {

    @IBOutlet weak var payTitleLabel: UILabel!
    @IBOutlet weak var biometricsPaySwitch: UISwitch!

    private let context = LAContext()
    private var biometryType: LABiometryType!

    override func viewDidLoad() {
        super.viewDidLoad()

        biometricsPaySwitch.isOn = WalletUserDefault.shared.isBiometricPay
        payTitleLabel.text = Localized.WALLET_ENABLE_BIOMETRIC_PAY_TITLE(biometricType: biometryType == .touchID ? Localized.WALLET_TOUCH_ID : Localized.WALLET_FACE_ID)
    }

    @IBAction func biometryPaySwitchAction(_ sender: Any) {
        if WalletUserDefault.shared.isBiometricPay {
            let title = Localized.WALLET_DISABLE_BIOMETRIC_PAY(biometricType: biometryType == .touchID ? Localized.WALLET_TOUCH_ID : Localized.WALLET_FACE_ID)
            let alc = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: { [weak self](_) in
                self?.biometricsPaySwitch.setOn(WalletUserDefault.shared.isBiometricPay, animated: true)
            }))
            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_DISABLE, style: .default, handler: { (_) in
                Keychain.shared.clearPIN()
                WalletUserDefault.shared.isBiometricPay = false
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
                }.presentPopupControllerAnimated()
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else {
            return nil
        }
        return Localized.WALLET_ENABLE_BIOMETRIC_PAY_PROMPT(biometricType: biometryType == .touchID ? Localized.WALLET_TOUCH_ID : Localized.WALLET_FACE_ID)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 {
            navigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .changePinStep1), animated: true)
        }
    }

    @IBAction func changePINAction(_ sender: Any) {
        navigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .changePinStep1), animated: true)
    }

    class func instance(biometryType: LABiometryType) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "wallet_setting") as! WalletSettingViewController
        vc.biometryType = biometryType
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_SETTING)
    }
}
