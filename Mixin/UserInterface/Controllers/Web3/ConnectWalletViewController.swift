import UIKit
import web3
import Web3Wallet
import MixinServices

final class ConnectWalletViewController: AuthenticationPreviewViewController {
    
    private let proposal: WalletConnectSign.Session.Proposal
    private let chains: [Web3Chain]
    private let events: [String]
    
    private var isProposalApproved = false
    
    init(
        proposal: WalletConnectSign.Session.Proposal,
        chains: [Web3Chain],
        events: [String]
    ) {
        self.proposal = proposal
        self.chains = chains
        self.events = events
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setIcon { imageView in
            let url = proposal.proposer.icons.lazy
                .compactMap(URL.init(string:))
                .first
            imageView.sd_setImage(with: url)
        }
        layoutTableHeaderView(title: R.string.localizable.connect_your_account(),
                              subtitle: R.string.localizable.connect_web3_account_description())
        
        let host = URL(string: proposal.proposer.url)?.host ?? proposal.proposer.url
        var rows: [Row] = [
            .proposer(name: proposal.proposer.name, host: host),
        ]
        let categories = Set(chains.map(\.category))
        if categories.contains(.evm), let account: String = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress) {
            rows.append(.info(caption: .account, content: account))
        }
        if categories.contains(.solana), let account: String = PropertiesDAO.shared.unsafeValue(forKey: .solanaAddress) {
            rows.append(.info(caption: .account, content: account))
        }
        reloadData(with: rows)
    }
    
    override func loadInitialTrayView(animated: Bool) {
        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                 leftAction: #selector(close(_:)),
                                 rightTitle: R.string.localizable.connect(),
                                 rightAction: #selector(confirm(_:)),
                                 animation: animated ? .vertical : nil)
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        rejectProposalIfNotApproved()
    }
    
    override func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        super.presentationControllerDidDismiss(presentationController)
        rejectProposalIfNotApproved()
    }
    
    override func performAction(with pin: String) {
        Logger.web3.info(category: "Connect", message: "Will connect")
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = R.string.localizable.connecting()
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached { [chains, proposal, events] in
            do {
                let evmAddress = try await {
                    let priv = try await TIP.deriveEthereumPrivateKey(pin: pin)
                    let keyStorage = InPlaceKeyStorage(raw: priv)
                    return try EthereumAccount(keyStorage: keyStorage).address.toChecksumAddress()
                }()
                let solanaAddress = try await {
                    let priv = try await TIP.deriveSolanaPrivateKey(pin: pin)
                    return try Solana.publicKey(seed: priv)
                }()
                let accounts: [WalletConnectUtils.Account] = chains.compactMap { chain in
                    switch chain.category {
                    case .evm:
                        WalletConnectUtils.Account(blockchain: chain.caip2, address: evmAddress)
                    case .solana:
                        WalletConnectUtils.Account(blockchain: chain.caip2, address: solanaAddress)
                    }
                }
                let methods = WalletConnectSession.Method.allCases.map(\.rawValue)
                let sessionNamespaces = try AutoNamespaces.build(sessionProposal: proposal,
                                                                 chains: chains.map(\.caip2),
                                                                 methods: methods,
                                                                 events: Array(events),
                                                                 accounts: accounts)
                _ = try await Web3Wallet.instance.approve(proposalId: proposal.id,
                                                          namespaces: sessionNamespaces)
                Logger.web3.info(category: "Connect", message: "Connected")
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.isProposalApproved = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.layoutTableHeaderView(title: R.string.localizable.web3_account_connected(),
                                               subtitle: R.string.localizable.connect_web3_account_description())
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadSingleButtonTrayView(title: R.string.localizable.done(),
                                                  action: #selector(self.close(_:)))
                }
            } catch {
                Logger.web3.error(category: "Connect", message: "Failed to approve: \(error)")
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .failure)
                    self.layoutTableHeaderView(title: R.string.localizable.connection_failed(),
                                               subtitle: error.localizedDescription)
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: R.string.localizable.retry(),
                                                  rightAction: #selector(self.confirm(_:)),
                                                  animation: .vertical)
                }
            }
        }
    }
    
    private func rejectProposalIfNotApproved() {
        guard !isProposalApproved else {
            return
        }
        Logger.web3.info(category: "Connect", message: "Rejected by dismissing")
        reject()
    }
    
}

extension ConnectWalletViewController: Web3PopupViewController {
    
    func reject() {
        Task {
            try await Web3Wallet.instance.rejectSession(proposalId: proposal.id, reason: .userRejected)
        }
    }
    
}
