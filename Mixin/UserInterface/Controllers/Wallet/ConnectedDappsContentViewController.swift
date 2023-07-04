import UIKit
import Web3Wallet

final class ConnectedDappsContentViewController: AuthorizationsContentViewController {
    
    var sessions: [WalletConnectSession] = [] {
        didSet {
            tableView.reloadData()
            tableView.checkEmpty(dataCount: sessions.count,
                                 text: R.string.localizable.no_dapp(),
                                 photo: R.image.emptyIndicator.ic_authorization()!)
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sessions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization, for: indexPath)!
        let session = self.session(at: indexPath)
        cell.iconImageView.imageView.sd_setImage(with: session.iconURL)
        cell.titleLabel.text = session.name
        cell.subtitleLabel.text = session.description
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let session = self.session(at: indexPath)
        let disconnect = ConnectedDappViewController.instance(session: session)
        navigationController?.pushViewController(disconnect, animated: true)
    }
    
    private func session(at indexPath: IndexPath) -> WalletConnectSession {
        sessions[indexPath.row]
    }
    
}
