import UIKit
import MixinServices

final class AddRecoveryContactViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.enable_emergency_contact(), titleStyle: .highlighted, accessory: .disclosure)
        ]),
    ])
    
    class func instance() -> UIViewController {
        let vc = AddRecoveryContactViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.emergency_contact())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.recoveryContactTableHeaderView(withOwner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension AddRecoveryContactViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch TIP.status {
        case .ready, .needsMigrate:
            let introduction = RecoveryContactIntroduction1ViewController.contained()
            navigationController?.pushViewController(introduction, animated: true)
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: .setEmergencyContact)
            navigationController?.present(tip, animated: true)
        case .unknown:
            break
        }
    }
    
}

extension AddRecoveryContactViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        UIApplication.shared.openURL(url: .emergencyContact)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_titlebar_help()
    }
    
}
