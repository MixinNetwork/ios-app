import UIKit
import MixinServices

final class DeleteAccountSettingViewController: SettingsTableViewController {

    private let tableHeaderView = R.nib.deleteAccountTableHeaderView(owner: nil)!
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
    
    class func instance() -> UIViewController {
        let vc = DeleteAccountSettingViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_delete_account())
    }
    
}

extension DeleteAccountSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if LoginManager.shared.account?.has_pin ?? false {
            indexPath.section == 0 ? verifyPIN() : changeNumber()
        } else {
            let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil)
            navigationController?.pushViewController(vc, animated: true)
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
            let assets = AssetDAO.shared.getAvailableAssets()
            DispatchQueue.main.async {
                hud.hide()
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
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true, completion: nil)
    }
    
    private func verifyNumber() {
        let vc = DeleteAccountVerifyNumberViewController.instance()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func verifyPIN() {
        let window = DeleteAccountVerifyPinWindow.instance()
        window.onSuccess = checkAvailableAssets
        window.presentPopupControllerAnimated()
    }
    
    private func presentDeleteAccountHintWindow(assets: [AssetItem]) {
        let window = DeleteAccountHintWindow.instance()
        window.onViewWallet = presentWallet
        window.onContinue = verifyNumber
        window.render(assets: assets)
        window.presentPopupControllerAnimated()
    }
 
    private func presentWallet() {
        let wallet = R.storyboard.wallet.wallet()!
        navigationController?.pushViewController(wallet, animated: true)
    }
    
}

