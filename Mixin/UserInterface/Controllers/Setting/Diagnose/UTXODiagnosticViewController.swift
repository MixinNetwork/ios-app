import UIKit
import MixinServices

final class UTXODiagnosticViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: "Reveal Public SpendKey", accessory: .none),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Reveal Outputs", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Delete Salt", titleStyle: .destructive, accessory: .none),
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension UTXODiagnosticViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let reveal = RevealPublicSpendKeyIntent()
            reveal.onReveal = { (publicKey) in
                let alert = UIAlertController(title: "Copy Public SpendKey", message: publicKey, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: R.string.localizable.copy(), style: .default, handler: { _ in
                    UIPasteboard.general.string = publicKey
                }))
                alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
                self.present(alert, animated: true)
            }
            let authentication = AuthenticationViewController(intent: reveal)
            present(authentication, animated: true)
        case (1, 0):
            let outputs = OutputsViewController(token: nil)
            let container = ContainerViewController.instance(viewController: outputs, title: "Outputs")
            navigationController?.pushViewController(container, animated: true)
        case (2, 0):
            AppGroupKeychain.encryptedSalt = nil
            Logger.general.warn(category: "UTXO", message: "Encrypted salt removed")
            showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
        default:
            break
        }
    }
    
}
