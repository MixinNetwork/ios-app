import UIKit
import MixinServices

class DeleteAccountViewController: SettingsTableViewController {

    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_delete_account(), titleStyle: .destructive)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.setting_change_number_instead())
        ])
    ])
    
    class func instance() -> UIViewController {
        let vc = DeleteAccountViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_delete_account())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.deleteAccountTableHeaderView(owner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension DeleteAccountViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            deleteAccount()
        } else {
            changeNumber()
        }
    }
    
}

extension DeleteAccountViewController {
    
    private func deleteAccount() {
        
    }
    
    private func changeNumber() {
        if LoginManager.shared.account?.has_pin ?? false {
            let vc = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
            present(vc, animated: true, completion: nil)
        } else {
            let vc = WalletPasswordViewController.instance(dismissTarget: .changePhone)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}

