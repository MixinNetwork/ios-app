import UIKit
import MixinServices

final class Web3DiagnosticViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: "Disconnect All Dapps", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Reset Transactions", accessory: .disclosure),
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
        case (1, 0):
            if let walletID = Web3WalletDAO.shared.classicWallet()?.walletID {
                Web3TransactionDAO.shared.deleteAll()
                let addresses = Web3AddressDAO.shared.addresses(walletID: walletID)
                let destinations = Set(addresses.map(\.destination))
                Web3PropertiesDAO.shared.deleteTransactionOffset(addresses: destinations)
                showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
            } else {
                showAutoHiddenHud(style: .error, text: "Missing Wallet")
            }            
        default:
            break
        }
    }
    
}
