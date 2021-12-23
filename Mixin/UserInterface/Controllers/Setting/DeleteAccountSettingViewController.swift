import UIKit
import MixinServices

final class DeleteAccountSettingViewController: SettingsTableViewController {

    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_delete_account(), titleStyle: .destructive)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_change_number_instead())
        ])
    ])
        
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.deleteAccountTableHeaderView(owner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    class func instance() -> UIViewController {
        let vc = DeleteAccountSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_delete_account())
    }
    
}

extension DeleteAccountSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if LoginManager.shared.account?.has_pin ?? false {
            if indexPath.section == 0 {
                deleteAccount()
            } else {
                changeNumber()
            }
        } else {
            let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}

extension DeleteAccountSettingViewController {
    
    private func deleteAccount() {
        DispatchQueue.global().async { [weak self] in
            let assets = AssetDAO.shared.getAvailableAssets()
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                if assets.isEmpty {
                    self.verifyNumber()
                } else {
                    self.presentDeleteAccountHintWindow(assets: assets)
                }
            }
        }
    }
    
    private func changeNumber() {
        let vc = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
        present(vc, animated: true, completion: nil)
    }
    
    private func verifyNumber() {
        let vc = DeleteAccountVerifyNumberViewController.instance()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentDeleteAccountHintWindow(assets: [AssetItem]) {
        func presentWindow() {
            let window = DeleteAccountHintWindow.instance()
            window.onViewWallet = presentWallet
            window.onContinue = verifyNumber
            window.render(assets: assets)
            window.presentPopupControllerAnimated()
        }
        if shouldValidatePin {
            let validator = PinValidationViewController(onSuccess: { (_) in
                presentWindow()
            })
            present(validator, animated: true, completion: nil)
        } else {
            presentWindow()
        }
    }
    
    private func presentWallet() {
        let wallet = R.storyboard.wallet.wallet()!
        if shouldValidatePin {
            let validator = PinValidationViewController(onSuccess: { (_) in
                self.navigationController?.pushViewController(wallet, animated: true)
            })
            present(validator, animated: true, completion: nil)
        } else {
            navigationController?.pushViewController(wallet, animated: true)
        }
    }
    
    private var shouldValidatePin: Bool {
        if let date = AppGroupUserDefaults.Wallet.lastPinVerifiedDate {
             return -date.timeIntervalSinceNow > AppGroupUserDefaults.Wallet.periodicPinVerificationInterval
        } else {
            AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
            return true
        }
    }
    
}

