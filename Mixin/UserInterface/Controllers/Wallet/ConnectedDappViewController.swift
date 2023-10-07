import UIKit
import Combine
import Web3Wallet

final class ConnectedDappViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.disconnect())
        ])
    ])
    
    private lazy var hud = Hud()
    private lazy var switchChainRow = SettingsRow(title: R.string.localizable.network(), subtitle: nil)
    
    private var sessionsSubscriber: AnyCancellable?
    
    private var session: WalletConnectSession? {
        didSet {
            reloadData()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance(session: WalletConnectSession) -> UIViewController {
        let dapp = ConnectedDappViewController()
        dapp.session = session
        let container = ContainerViewController.instance(viewController: dapp, title: "")
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
    }
    
    func reloadData() {
        guard isViewLoaded, let session else {
            return
        }
        let tableHeaderView = R.nib.connectedDappTableHeaderView(withOwner: nil)!
        tableHeaderView.imageView.sd_setImage(with: session.iconURL)
        tableHeaderView.nameLabel.text = session.name
        tableHeaderView.hostLabel.text = session.host
        tableView.tableHeaderView = tableHeaderView
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        sessionsSubscriber = WalletConnectService.shared.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                let hasCurrentSession = sessions.contains {
                    $0.topic == session.topic
                }
                if let self, !hasCurrentSession {
                    self.navigationController?.popViewController(animated: true)
                }
            }
    }
    
    private func disconnect() {
        guard let session else {
            return
        }
        let hud = self.hud
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Task {
            let disconnectError: Error?
            do {
                try await session.disconnect()
                disconnectError = nil
            } catch {
                disconnectError = error
            }
            await MainActor.run {
                if let error = disconnectError {
                    hud.set(style: .error, text: error.localizedDescription)
                } else {
                    hud.set(style: .notification, text: R.string.localizable.disconnected())
                }
                hud.scheduleAutoHidden()
            }
        }
    }
    
}

extension ConnectedDappViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        disconnect()
    }
    
}
