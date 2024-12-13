import UIKit
import MixinServices

final class ViewRecoveryContactViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.view_emergency_contact(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.change_emergency_contact(), accessory: .disclosure)
        ]),
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.remove_emergency_contact(), titleStyle: .destructive)
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.emergency_contact()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_titlebar_help(),
            target: self,
            action: #selector(help(_:))
        )
        tableView.tableHeaderView = R.nib.recoveryContactTableHeaderView(withOwner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    @objc private func help(_ sender: Any) {
        UIApplication.shared.openURL(url: .recoveryContact)
    }
    
}

extension ViewRecoveryContactViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            let validator = ShowRecoveryContactValidationViewController()
            present(validator, animated: true, completion: nil)
        case 1:
            let verifyPIN = RecoveryContactVerifyPINViewController()
            navigationController?.pushViewController(verifyPIN, animated: true)
        default:
            let alert = UIAlertController(title: R.string.localizable.remove_emergency_contact_for_sure(), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.delete(), style: .destructive, handler: { (_) in
                let validator = RemoveRecoveryContactValidationViewController()
                self.present(validator, animated: true, completion: nil)
            }))
            present(alert, animated: true, completion: nil)
        }
    }
    
}
