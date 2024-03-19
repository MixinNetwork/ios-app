import UIKit
import Combine
import MixinServices

final class Web3WalletViewController: UIViewController {
    
    private struct EmbeddedDapp {
        
        static let uniswap = EmbeddedDapp(
            name: "Uniswap",
            host: "app.uniswap.org",
            url: URL(string: "https://app.uniswap.org"),
            icon: R.image.explore.uniswap()!,
            session: nil
        )
        
        static let snapshot = EmbeddedDapp(
            name: "Snapshot",
            host: "snapshot.org",
            url: URL(string: "https://snapshot.org"),
            icon: R.image.explore.snapshot()!, 
            session: nil
        )
        
        let name: String
        let host: String
        let url: URL?
        let icon: UIImage
        let session: WalletConnectSession?
        
        func replacingSession(with session: WalletConnectSession?) -> EmbeddedDapp {
            if let session {
                EmbeddedDapp(name: session.name,
                             host: session.host,
                             url: session.url,
                             icon: icon,
                             session: session)
            } else {
                EmbeddedDapp(name: name,
                             host: host,
                             url: url,
                             icon: icon,
                             session: nil)
            }
        }
        
    }
    
    private enum Section: Int, CaseIterable {
        case embedded = 0
        case session
    }
    
    private let tableView = UITableView()
    private let tableHeaderView = R.nib.web3WalletHeaderView(withOwner: nil)!
    private let chain: WalletConnectService.Chain
    
    private var sessionsObserver: AnyCancellable?
    
    private var embeddedDapps: [EmbeddedDapp] = [.uniswap, .snapshot]
    private var sessions: [WalletConnectSession] = []
    
    private var address: String?
    
    init(chain: WalletConnectService.Chain) {
        self.chain = chain
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.backgroundColor = R.color.background()
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        tableView.register(R.nib.web3DappCell)
        tableView.dataSource = self
        tableView.delegate = self
        
        tableHeaderView.showUnlockAccount(chain: chain)
        tableHeaderView.frame.size.height = 134
        tableHeaderView.delegate = self
        tableView.tableHeaderView = tableHeaderView
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(propertiesDidUpdate(_:)),
                                               name: PropertiesDAO.propertyDidUpdateNotification,
                                               object: nil)
        DispatchQueue.global().async { [chain] in
            let address: String? = PropertiesDAO.shared.value(forKey: .evmAccount)
            DispatchQueue.main.async {
                if address == nil {
                    self.tableHeaderView.showUnlockAccount(chain: chain)
                } else {
                    self.tableHeaderView.showCopyAddress(chain: chain)
                }
            }
        }
        
        sessionsObserver = WalletConnectService.shared.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.load(sessions: sessions)
            }
        self.load(sessions: WalletConnectService.shared.sessions)
    }
    
    @objc private func propertiesDidUpdate(_ notification: Notification) {
        address = notification.userInfo?[PropertiesDAO.Key.evmAccount] as? String
        if address != nil {
            tableHeaderView.showCopyAddress(chain: chain)
        }
    }
    
    private func load(sessions: [WalletConnectSession]) {
        var externalSessions = sessions // `sessions` subtracting embeddeds
        self.embeddedDapps = embeddedDapps.map { dapp in
            if let index = externalSessions.firstIndex(where: { $0.host == dapp.host }) {
                let session = externalSessions[index]
                externalSessions.remove(at: index)
                return dapp.replacingSession(with: session)
            } else {
                return dapp
            }
        }
        self.sessions = externalSessions
        tableView.reloadData()
    }
    
}

// MARK: - Web3WalletHeaderView Delegate
extension Web3WalletViewController: Web3WalletHeaderView.Delegate {
    
    func web3WalletHeaderViewRequestToCreateAccount(_ view: Web3WalletHeaderView) {
        let unlock = UnlockWeb3WalletViewController(chain: chain)
        present(unlock, animated: true)
    }
    
    func web3WalletHeaderViewRequestToCopyAddress(_ view: Web3WalletHeaderView) {
        guard let address: String = PropertiesDAO.shared.value(forKey: .evmAccount) else {
            return
        }
        UIPasteboard.general.string = address
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

// MARK: - UITableViewDataSource
extension Web3WalletViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .embedded:
            embeddedDapps.count
        case .session:
            sessions.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_dapp, for: indexPath)!
        switch Section(rawValue: indexPath.section)! {
        case .embedded:
            let dapp = embeddedDapps[indexPath.row]
            cell.iconImageView.image = dapp.icon
            cell.nameLabel.text = dapp.name
            cell.hostLabel.text = dapp.host
        case .session:
            let session = sessions[indexPath.row]
            cell.iconImageView.sd_setImage(with: session.iconURL)
            cell.nameLabel.text = session.name
            cell.hostLabel.text = session.host
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension Web3WalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let container = UIApplication.homeContainerViewController?.homeTabBarController {
            let url = switch Section(rawValue: indexPath.section)! {
            case .embedded:
                embeddedDapps[indexPath.row].url
            case .session:
                sessions[indexPath.row].url
            }
            if let url {
                MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url),
                                                       asChildOf: container)
            }
        }
    }
    
}
