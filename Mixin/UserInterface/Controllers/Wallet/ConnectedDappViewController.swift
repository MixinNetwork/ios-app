import UIKit
import Combine
import Web3Wallet

final class ConnectedDappViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: "Disconnect")
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
        let tableHeaderView = R.nib.connectedDappTableHeaderView(owner: nil)!
        tableHeaderView.imageView.sd_setImage(with: session.iconURL)
        tableHeaderView.nameLabel.text = session.name
        tableHeaderView.hostLabel.text = session.host
        tableView.tableHeaderView = tableHeaderView
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        if let currentSession = session as? WalletConnectV1Session {
            switchChainRow.subtitle = currentSession.chain.name
            dataSource.insertSection(SettingsSection(rows: [switchChainRow]), at: 0, animation: .none)
            sessionsSubscriber = WalletConnectService.shared.$v1Sessions
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessions in
                    let hasCurrentSession = sessions.contains { session in
                        session.topic == currentSession.topic
                    }
                    if let self, !hasCurrentSession {
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(updateNetworkSubtitle),
                                                   name: WalletConnectV1Session.didUpdateNotification,
                                                   object: currentSession)
        } else if let currentSession = session as? WalletConnectV2Session {
            sessionsSubscriber = WalletConnectService.shared.$v2Sessions
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessions in
                    let hasCurrentSession = sessions.contains { session in
                        session.topic == currentSession.topic
                    }
                    if let self, !hasCurrentSession {
                        self.navigationController?.popViewController(animated: true)
                    }
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
    
    private func presentChainSelection(session: WalletConnectV1Session) {
        let sheet = UIAlertController(title: R.string.localizable.switch_network(), message: nil, preferredStyle: .actionSheet)
        for chain in WalletConnectService.supportedChains.values {
            sheet.addAction(UIAlertAction(title: chain.name, style: .default) { _ in
                self.switch(session: session, to: chain)
            })
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func `switch`(session: WalletConnectV1Session, to chain: WalletConnectService.Chain) {
        do {
            try session.switch(to: chain)
        } catch {
            showAutoHiddenHud(style: .error, text: error.localizedDescription)
        }
    }
    
    @objc private func updateNetworkSubtitle(_ notification: Notification) {
        guard let session = notification.object as? WalletConnectV1Session else {
            return
        }
        switchChainRow.subtitle = session.chain.name
    }
    
}

extension ConnectedDappViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let session = session as? WalletConnectV1Session {
            switch indexPath.section {
            case 0:
                presentChainSelection(session: session)
            default:
                disconnect()
            }
        } else {
            disconnect()
        }
    }
    
}
