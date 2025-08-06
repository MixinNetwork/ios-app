import UIKit
import web3
import ReownWalletKit
import MixinServices

final class ConnectWalletViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    private let wallet: Web3Wallet
    private let addresses: [Web3Chain: Web3Address]
    private let proposal: WalletConnectSign.Session.Proposal
    private let events: [String]
    
    private var isProposalApproved = false
    
    init(
        wallet: Web3Wallet,
        addresses: [Web3Chain: Web3Address],
        proposal: WalletConnectSign.Session.Proposal,
        events: [String]
    ) {
        self.wallet = wallet
        self.addresses = addresses
        self.proposal = proposal
        self.events = events
        super.init(wallet: .common(wallet), warnings: [])
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
        layoutTableHeaderView(
            title: R.string.localizable.connect_your_wallet(),
            subtitle: R.string.localizable.connect_web3_wallet_description()
        )
        
        let host = URL(string: proposal.proposer.url)?.host ?? proposal.proposer.url
        var rows: [Row] = [
            .doubleLineInfo(caption: .from, primary: proposal.proposer.name, secondary: host)
        ]
        
        var evmAddress: String?
        var solanaAddress: String?
        for (chain, address) in addresses {
            if evmAddress == nil, chain.kind == .evm {
                evmAddress = address.destination
            } else if solanaAddress == nil, chain.kind == .solana {
                solanaAddress = address.destination
            }
            if evmAddress != nil && solanaAddress != nil {
                break
            }
        }
        if let evmAddress {
            rows.append(.address(
                caption: .wallet,
                address: evmAddress,
                label: .wallet(.common(wallet))
            ))
        }
        if let solanaAddress {
            rows.append(.address(
                caption: .wallet,
                address: solanaAddress,
                label: .wallet(.common(wallet))
            ))
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
        Task.detached { [addresses, proposal, events] in
            do {
                let accounts = try addresses.map { (chain, address) in
                    try WalletConnectUtils.Account(
                        blockchain: chain.caip2,
                        accountAddress: address.destination
                    )
                }
                try await withCheckedThrowingContinuation { continuation in
                    AccountAPI.verify(pin: pin) { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                let methods = WalletConnectSession.Method.allCases.map(\.rawValue)
                let sessionNamespaces = try AutoNamespaces.build(
                    sessionProposal: proposal,
                    chains: addresses.keys.map(\.caip2),
                    methods: methods,
                    events: Array(events),
                    accounts: accounts
                )
                _ = try await WalletKit.instance.approve(
                    proposalId: proposal.id,
                    namespaces: sessionNamespaces
                )
                Logger.web3.info(category: "Connect", message: "Connected")
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.isProposalApproved = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.layoutTableHeaderView(
                        title: R.string.localizable.web3_wallet_connected(),
                        subtitle: R.string.localizable.connect_web3_wallet_description()
                    )
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
            try await WalletKit.instance.rejectSession(proposalId: proposal.id, reason: .userRejected)
        }
    }
    
}
