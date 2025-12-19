import UIKit
import MixinServices

final class DeleteAccountSettingViewController: SettingsTableViewController, LogoutHandler {
    
    private let tableHeaderView = R.nib.deleteAccountTableHeaderView(withOwner: nil)!
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.delete_my_account(), titleStyle: .destructive)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.log_out_instead()),
            SettingsRow(title: R.string.localizable.change_number_instead()),
        ])
    ])
    
    private lazy var captcha = Captcha(viewController: self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.delete_my_account()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        updateTableHeaderView()
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
    
}

extension DeleteAccountSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            verifyPIN()
        default:
            switch indexPath.row {
            case 0:
                presentLogoutConfirmationAlert()
            default:
                changeNumber()
            }
        }
    }
    
}

extension DeleteAccountSettingViewController {
    
    private func updateTableHeaderView() {
        let sizeToFit = CGSize(width: view.bounds.width, height: UIView.layoutFittingExpandedSize.height)
        let headerHeight = tableHeaderView.sizeThatFits(sizeToFit).height
        tableHeaderView.frame.size = CGSize(width: view.bounds.width, height: headerHeight)
        tableView.tableHeaderView = tableHeaderView
    }
    
    private func checkAvailableAssets() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async { [weak self] in
            let assets = TokenDAO.shared.positiveBalancedTokens()
            DispatchQueue.main.async {
                hud.hide()
                guard let self = self else {
                    return
                }
                if assets.isEmpty {
                    self.presentVerificationConfirmation()
                } else {
                    self.presentDeleteAccountHintWindow(assets: assets)
                }
            }
        }
    }
    
    private func changeNumber() {
        let verify = ChangeNumberPINValidationViewController()
        navigationController?.pushViewController(verify, animated: true)
    }
    
    private func presentVerificationConfirmation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        let message: String?
        let phoneNumber: String?
        if let phone = account.phone, !account.isAnonymous {
            message = R.string.localizable.setting_delete_account_send(phone)
            phoneNumber = phone
        } else {
            message = nil
            phoneNumber = nil
        }
        let controller = UIAlertController(title: R.string.localizable.delete_my_account(), message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .default, handler: nil))
        if let phoneNumber {
            controller.addAction(UIAlertAction(title: R.string.localizable.continue(), style: .default, handler: { _ in
                self.requestVerificationCode(for: phoneNumber, captchaToken: nil)
            }))
        } else {
            controller.addAction(UIAlertAction(title: R.string.localizable.delete(), style: .destructive, handler: { _ in
                DeleteAccountConfirmWindow
                    .instance(verificationID: nil)
                    .presentPopupControllerAnimated()
            }))
        }
        present(controller, animated: true, completion: nil)
    }
    
    private func verifyPIN() {
        let window = DeleteAccountVerifyPinWindow.instance()
        window.onSuccess = checkAvailableAssets
        window.presentPopupControllerAnimated()
    }
    
    private func presentDeleteAccountHintWindow(assets: [MixinTokenItem]) {
        let window = DeleteAccountHintWindow.instance()
        window.onViewWallet = { [weak self] in
            self?.presentWallet()
        }
        window.onContinue = { [weak self] in
            self?.presentVerificationConfirmation()
        }
        window.render(assets: assets)
        window.presentPopupControllerAnimated()
    }
    
    private func presentWallet() {
        UIApplication.homeNavigationController?.popToRootViewController(animated: false)
        if let tabBarController = UIApplication.homeContainerViewController?.homeTabBarController {
            tabBarController.switchTo(child: .wallet)
            if let container = tabBarController.selectedViewController as? WalletContainerViewController {
                container.switchToWalletSummary(animated: false)
            }
        }
    }
    
    private func requestVerificationCode(for phone: String, captchaToken token: CaptchaToken?) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        AccountAPI.deactivateVerifications(phoneNumber: phone, captchaToken: token) { [weak self] (result) in
            guard let self else {
                return
            }
            hud.hide()
            switch result {
            case .success(let verification):
                let context = DeleteAccountContext(phoneNumber: phone, verificationID: verification.id)
                let vc = DeleteAccountVerifyCodeViewController(context: context)
                self.navigationController?.pushViewController(vc, animated: true)
            case let .failure(.response(error)) where .requiresCaptcha ~= error:
                self.captcha.validate(errorDescription: error.description) { [weak self] (result) in
                    switch result {
                    case .success(let token):
                        self?.requestVerificationCode(for: phone, captchaToken: token)
                    case .cancel, .timedOut:
                        hud.hide()
                    }
                }
            case let .failure(error):
                self.alert(error.localizedDescription)
            }
        }
    }
    
}

