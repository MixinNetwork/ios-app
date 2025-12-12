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
        SettingsSection(rows: [
            SettingsRow(
                title: "Low EVM Fee",
                accessory: .switch(
                    isOn: Web3Diagnostic.usesLowEVMFeeOnce,
                    isEnabled: true
                )
            )
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Remove Imported Secrets", accessory: .disclosure),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Reset Trade Orders"),
        ]),
        SettingsSection(rows: [
            SettingsRow(title: "Delete Safe Vaults"),
        ]),
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Web3"
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(switchEVMFee(_:)),
            name: SettingsRow.accessoryDidChangeNotification,
            object: dataSource.sections[2].rows[0]
        )
    }
    
    @objc private func switchEVMFee(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard case let .switch(isOn, _) = row.accessory else {
            return
        }
        Web3Diagnostic.usesLowEVMFeeOnce = isOn
    }
    
}

extension Web3DiagnosticViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            WalletConnectService.shared.disconnectAllSessions()
            showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
        case (1, 0):
            Web3TransactionDAO.shared.deleteAll()
            for walletID in Web3WalletDAO.shared.walletIDs() {
                let destinations = Web3AddressDAO.shared.destinations(walletID: walletID)
                Web3PropertiesDAO.shared.deleteTransactionOffset(addresses: destinations)
            }
            showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
        case (3, 0):
            AppGroupKeychain.deleteAllImportedMnemonics()
            AppGroupKeychain.deleteAllImportedPrivateKey()
            showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
        case (4, 0):
            Web3OrderDAO.shared.deleteAll()
            Web3PropertiesDAO.shared.deleteAllOrderOffsets()
            showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
        case (5, 0):
            Web3WalletDAO.shared.replaceSafeWallets(wallets: [], tokens: []) { }
            showAutoHiddenHud(style: .notification, text: R.string.localizable.deleted())
        default:
            break
        }
    }
    
}
