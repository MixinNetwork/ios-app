import UIKit
import MixinServices

final class Web3DiagnosticViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: "Disconnect All Dapps", accessory: .disclosure),
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Web3"
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension Web3DiagnosticViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            WalletConnectService.shared.disconnectAllSessions()
            showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
        default:
            break
        }
    }
    
}
