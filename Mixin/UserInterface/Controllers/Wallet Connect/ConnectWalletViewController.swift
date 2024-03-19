import UIKit
import web3
import Web3Wallet
import MixinServices

final class ConnectWalletViewController: AuthenticationPreviewViewController {
    
    private let proposal: WalletConnectSign.Session.Proposal
    private let chains: [Blockchain]
    private let events: [String]
    
    private var isProposalApproved = false
    
    init(
        proposal: WalletConnectSign.Session.Proposal,
        chains: [Blockchain],
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
            if let icon = proposal.proposer.icons.first, let url = URL(string: icon) {
                imageView.sd_setImage(with: url)
            }
        }
        layoutTableHeaderView(title: R.string.localizable.connect_your_account(),
                              subtitle: R.string.localizable.connect_web3_account_description())
        
        let host = URL(string: proposal.proposer.url)?.host ?? proposal.proposer.url
        var rows: [Row] = [
            .proposer(name: proposal.proposer.name, host: host),
        ]
        if let account: String = PropertiesDAO.shared.value(forKey: .evmAccount) {
            // FIXME: Get account by `self.chains`
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
        rejectProposalIfNotApproved()
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = R.string.localizable.connecting()
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached { [chains, proposal, events] in
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                let address = try EthereumAccount(keyStorage: keyStorage).address.toChecksumAddress()
                let accounts = chains.compactMap { chain in
                    WalletConnectUtils.Account(blockchain: chain, address: address)
                }
                let methods = WalletConnectSession.Method.allCases.map(\.rawValue)
                let sessionNamespaces = try AutoNamespaces.build(sessionProposal: proposal,
                                                                 chains: chains,
                                                                 methods: methods,
                                                                 events: Array(events),
                                                                 accounts: accounts)
                try await Web3Wallet.instance.approve(proposalId: proposal.id,
                                                      namespaces: sessionNamespaces)
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.isProposalApproved = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.tableHeaderView.titleLabel.text = R.string.localizable.connected()
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadSingleButtonTrayView(title: R.string.localizable.done(),
                                                  action: #selector(self.close(_:)))
                }
            } catch {
                Logger.walletConnect.warn(category: "ConnectWallet", message: "Failed to approve: \(error)")
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
        Task {
            try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .userRejected)
        }
    }
    
}
