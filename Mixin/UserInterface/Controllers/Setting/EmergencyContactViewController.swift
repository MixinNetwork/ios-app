import UIKit

final class EmergencyContactViewController: UITableViewController {
    
    private let footerReuseId = "footer"
    
    private var hasEmergencyContact: Bool {
        return Account.current?.has_emergency_contact ?? false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.emergency_contact()!
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_emergency_contact())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.settingCell)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: footerReuseId)
        NotificationCenter.default.addObserver(self, selector: #selector(accountDidChange(_:)), name: .AccountDidChange, object: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return hasEmergencyContact ? 3 : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!
        if hasEmergencyContact {
            switch indexPath.section {
            case 0:
                cell.titleLabel.text = R.string.localizable.emergency_view()
                cell.accessoryImageView.isHidden = false
                cell.titleLabel.textColor = .text
            case 1:
                cell.titleLabel.text = R.string.localizable.emergency_change()
                cell.accessoryImageView.isHidden = false
                cell.titleLabel.textColor = .text
            default:
                cell.titleLabel.text = R.string.localizable.emergency_remove()
                cell.accessoryImageView.isHidden = true
                cell.titleLabel.textColor = .walletRed
            }
        } else {
            cell.titleLabel.text = R.string.localizable.enable_emergency_contact()
            cell.accessoryImageView.isHidden = true
            cell.titleLabel.textColor = .theme
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        view.shadowView.hasLowerShadow = false
        return view
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
    
    @objc func accountDidChange(_ notification: Notification) {
        tableView.reloadData()
    }
    
    private func viewEmergencyContact() {
        let validator = ShowEmergencyContactValidationViewController()
        present(validator, animated: true, completion: nil)
    }
    
    private func changeEmergencyContact() {
        guard let account = Account.current else {
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
            guard let account = Account.current else {
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

extension EmergencyContactViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        UIApplication.shared.openURL(url: .emergencyContact)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_titlebar_help()
    }
    
}
