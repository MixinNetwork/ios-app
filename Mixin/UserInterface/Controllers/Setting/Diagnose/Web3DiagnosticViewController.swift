import UIKit
import MixinServices

final class Web3DiagnosticViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: "Lock Account", accessory: .none),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Disconnect All Dapps", accessory: .disclosure),
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension Web3DiagnosticViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            DispatchQueue.global().async {
                PropertiesDAO.shared.removeValue(forKey: .evmAccount)
            }
            showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
        case (1, 0):
            Task {
                let sessions = WalletConnectService.shared.sessions
                for session in sessions {
                    try? await session.disconnect()
                }
            }
            showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
        default:
            break
        }
    }
    
}
