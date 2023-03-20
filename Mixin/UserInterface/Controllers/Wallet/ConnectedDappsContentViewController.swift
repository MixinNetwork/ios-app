import UIKit
import Web3Wallet

final class ConnectedDappsContentViewController: AuthorizationsContentViewController {
    
    var v1Sessions: [WalletConnectV1Session] = [] {
        didSet {
            tableView.reloadData()
            tableView.checkEmpty(dataCount: v1Sessions.count + v2Sessions.count,
                                 text: R.string.localizable.no_dapp(),
                                 photo: R.image.emptyIndicator.ic_authorization()!)
        }
    }
    
    var v2Sessions: [WalletConnectV2Session] = [] {
        didSet {
            tableView.reloadData()
            tableView.checkEmpty(dataCount: v1Sessions.count + v2Sessions.count,
                                 text: R.string.localizable.no_dapp(),
                                 photo: R.image.emptyIndicator.ic_authorization()!)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return v1Sessions.count
        } else {
            return v2Sessions.count
        }
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
        if indexPath.section == 0 {
            return v1Sessions[indexPath.row]
        } else {
            return v2Sessions[indexPath.row]
        }
    }
    
}
