import UIKit
import MixinServices

final class EmergencyContactViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [])
    
    private lazy var hasEmergencyContactSections = [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.emergency_view(), titleStyle: .normal, accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.emergency_change(), titleStyle: .normal, accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.emergency_remove(), titleStyle: .destructive)
        ])
    ]
    
    private lazy var noEmergencyContactSections = [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.enable_emergency_contact(), titleStyle: .highlighted, accessory: .disclosure)
        ])
    ]
    
    private var hasEmergencyContact: Bool {
        LoginManager.shared.account?.has_emergency_contact ?? false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance() -> UIViewController {
        let vc = EmergencyContactViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_emergency_contact())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
        tableView.tableHeaderView = R.nib.emergencyContactTableHeaderView(owner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: LoginManager.accountDidChangeNotification, object: nil)
    }
    
    @objc func reloadData() {
        if hasEmergencyContact {
            dataSource.reloadSections(hasEmergencyContactSections)
        } else {
            dataSource.reloadSections(noEmergencyContactSections)
        }
    }
    
}

extension EmergencyContactViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if hasEmergencyContact {
            switch indexPath.section {
            case 0:
                viewEmergencyContact()
            case 1:
                changeEmergencyContact()
            default:
                removeEmergencyContact()
            }
        } else {
            enableEmergencyContact()
        }
    }
    
}

extension EmergencyContactViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        UIApplication.shared.openURL(url: .emergencyContact)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_titlebar_help()
    }
    
}

extension EmergencyContactViewController {
    
    private func viewEmergencyContact() {
        let validator = ShowEmergencyContactValidationViewController()
        present(validator, animated: true, completion: nil)
    }
    
    private func changeEmergencyContact() {
        guard let account = LoginManager.shared.account else {
            return
        }
        if account.has_pin {
            let vc = EmergencyContactVerifyPinViewController()
            let navigationController = VerifyPinNavigationController(rootViewController: vc)
            present(navigationController, animated: true, completion: nil)
        } else {
            let vc = WalletPasswordViewController.instance(dismissTarget: .setEmergencyContact)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func removeEmergencyContact() {
        let alert = UIAlertController(title: R.string.localizable.emergency_tip_remove(), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.action_remove(), style: .destructive, handler: { (_) in
            let validator = RemoveEmergencyContactValidationViewController()
            self.present(validator, animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func enableEmergencyContact() {
        let vc = EmergencyTipsViewController.instance()
        vc.onNext = { [weak self] in
            guard let account = LoginManager.shared.account else {
                return
            }
            if account.has_pin {
                let vc = EmergencyContactVerifyPinViewController()
                let nav = VerifyPinNavigationController(rootViewController: vc)
                self?.navigationController?.present(nav, animated: true, completion: nil)
            } else {
                let vc = WalletPasswordViewController.instance(dismissTarget: .setEmergencyContact)
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        }
        present(vc, animated: true, completion: nil)
    }
    
}
