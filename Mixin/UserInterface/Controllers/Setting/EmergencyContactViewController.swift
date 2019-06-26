import UIKit

final class EmergencyContactViewController: UITableViewController {
    
    private let footerReuseId = "footer"
    
    private var hasEmergencyContact: Bool {
        return AccountAPI.shared.account?.has_emergency_contact ?? false
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
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return hasEmergencyContact ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!
        if hasEmergencyContact {
            if indexPath.section == 0 {
                cell.titleLabel.text = R.string.localizable.emergency_view()
            } else {
                cell.titleLabel.text = R.string.localizable.emergency_change()
            }
            cell.accessoryImageView.isHidden = false
            cell.titleLabel.textColor = .darkText
        } else {
            cell.titleLabel.text = R.string.localizable.enable_emergency_contact()
            cell.accessoryImageView.isHidden = true
            cell.titleLabel.textColor = .actionText
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        view.text = hasEmergencyContact ? nil : R.string.localizable.emergency_tip_before()
        view.shadowView.hasLowerShadow = false
        return view
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if hasEmergencyContact {
            if indexPath.section == 0 {
                viewEmergencyContact()
            } else {
                changeEmergencyContact()
            }
        } else {
            enableEmergencyContact()
        }
    }
    
    private func viewEmergencyContact() {
        let validator = ShowEmergencyContactValidationViewController()
        present(validator, animated: true, completion: nil)
    }
    
    private func changeEmergencyContact() {
        guard let account = AccountAPI.shared.account else {
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
    
    private func enableEmergencyContact() {
        let vc = EmergencyTipsViewController.instance()
        vc.onNext = { [weak self] in
            guard let account = AccountAPI.shared.account else {
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
        let vc = EmergencyTipsViewController.instance()
        present(vc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_titlebar_help()
    }
    
}
