import Foundation
import Combine
import OrderedCollections
import BigInt
import web3
import Auth
import Web3Wallet
import MixinServices

fileprivate var logger: MixinServices.Logger {
    .walletConnect
}

final class WalletConnectService {
    
    static let shared = WalletConnectService()
    
    static var isAccountAllowed: Bool {
        LoginManager.shared.account?.features.contains("tip") ?? false
    }
    
    static var isAvailable: Bool {
        guard isAccountAllowed else {
            return false
        }
        switch TIP.status {
        case .ready:
            return true
        case .needsMigrate, .needsInitialize, .unknown:
            return false
        }
    }
    
    @Published
    private(set) var sessions: [WalletConnectSession] = []
    
    private let walletName = "Mixin Messenger"
    private let walletDescription = "An open source cryptocurrency wallet with Signal messaging. Fully non-custodial and recoverable with phone number and TIP."
    
    private var connectionHud: Hud?
    private var subscribes = Set<AnyCancellable>()
    
    // Only one request or proposal can be presented at a time
    // New incoming requests will be rejected if `presentedViewController` is not nil
    private weak var presentedViewController: UIViewController?
    
    private init() {
        Networking.configure(groupIdentifier: appGroupIdentifier,
                             projectId: MixinKeys.walletConnect,
                             socketFactory: StarscreamFactory())
        let meta = AppMetadata(name: walletName,
                               description: walletDescription,
                               url: URL.mixinMessenger.absoluteString,
                               icons: ["https://mixin.one/assets/eccaf16dd38b2210f935.png"],
                               redirect: .init(native: "mixin://", universal: nil))
        Web3Wallet.configure(metadata: meta, crypto: Web3CryptoProvider())
        Web3Wallet.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.reloadSessions()
            }
            .store(in: &subscribes)
        Web3Wallet.instance.sessionProposalPublisher
            .sink { [weak self] (proposal, context) in
                DispatchQueue.main.async {
                    self?.show(proposal: proposal)
                }
            }
            .store(in: &subscribes)
        Web3Wallet.instance.sessionRequestPublisher
            .sink { [weak self] (request, context) in
                self?.handle(request: request)
            }
            .store(in: &subscribes)
    }
    
    func reloadSessions() {
        let sessions = Sign.instance.getSessions().map(WalletConnectSession.init(session:))
        let topics = sessions.map(\.topic)
        self.sessions = sessions
        Task {
            do {
                try await Relay.instance.batchSubscribe(topics: topics)
            } catch {
                logger.error(category: "WalletConnectService", message: "Failed to subscribe: \(error)")
            }
        }
    }
    
    func connect(to uri: WalletConnectURI) {
        logger.debug(category: "WalletConnectService", message: "Will connect to v2 topic: \(uri.topic)")
        assert(Thread.isMainThread)
        let hud = loadHud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Task {
            do {
                try await Web3Wallet.instance.pair(uri: uri)
            } catch {
                logger.error(category: "WalletConnectService", message: "Failed to connect to: \(uri.absoluteString), error: \(error)")
                await MainActor.run {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }
    }
    
    func presentRequest(viewController: UIViewController) {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        guard presentedViewController == nil else {
            presentRejection(title: R.string.localizable.request_rejected(),
                             message: R.string.localizable.request_rejected_reason_another_request_in_process())
            return
        }
        container.presentOnTopMostPresentedController(viewController, animated: true)
        presentedViewController = viewController
    }
    
    func presentRejection(title: String, message: String) {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .cancel))
        container.presentOnTopMostPresentedController(alert, animated: true)
    }
    
    private func loadHud() -> Hud {
        let hud: Hud
        if let connectionHud {
            hud = connectionHud
        } else {
            hud = Hud()
            connectionHud = hud
        }
        return hud
    }
    
}

// MARK: - Chain
extension WalletConnectService {
    
    struct Chain: Equatable {
        
        static let ethereum = Chain(
            id: 1,
            internalID: ChainID.ethereum,
            name: "Ethereum",
            rpcServerURL: URL(string: "https://cloudflare-eth.com")!,
            gasSymbol: "ETH",
            caip2: Blockchain("eip155:1")!
        )
        static let goerli = Chain(
            id: 5,
            internalID: ChainID.ethereum,
            name: "Goerli",
            rpcServerURL: URL(string: "https://rpc.ankr.com/eth_goerli")!,
            gasSymbol: "ETH",
            caip2: Blockchain("eip155:5")!
        )
        static let bnbSmartChain = Chain(
            id: 56,
            internalID: ChainID.bnbSmartChain,
            name: "Binance Smart Chain",
            rpcServerURL: URL(string: "https://endpoints.omniatech.io/v1/bsc/mainnet/public")!,
            gasSymbol: "BNB",
            caip2: Blockchain("eip155:56")!
        )
        static let polygon = Chain(
            id: 137,
            internalID: ChainID.polygon,
            name: "Polygon",
            rpcServerURL: URL(string: "https://polygon-rpc.com")!,
            gasSymbol: "MATIC",
            caip2: Blockchain("eip155:137")!
        )
        static let arbitrum = Chain(
            id: 42161,
            internalID: ChainID.arbitrum,
            name: "Arbitrum One",
            rpcServerURL: URL(string: "https://arb1.arbitrum.io/rpc")!,
            gasSymbol: "ETH",
            caip2: Blockchain("eip155:42161")!
        )
        static let optimism = Chain(
            id: 10,
            internalID: ChainID.optimism,
            name: "OP Mainnet",
            rpcServerURL: URL(string: "https://mainnet.optimism.io")!,
            gasSymbol: "ETH",
            caip2: Blockchain("eip155:10")!
        )
        
        let id: Int
        let internalID: String
        let name: String
        let rpcServerURL: URL
        let gasSymbol: String
        let caip2: Blockchain
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
    }
    
    static let supportedChains: OrderedDictionary<Int, Chain> = {
        var chains: OrderedDictionary<Int, Chain> = [
            Chain.ethereum.id:      .ethereum,
            Chain.bnbSmartChain.id: .bnbSmartChain,
            Chain.polygon.id:       .polygon,
            Chain.arbitrum.id:      .arbitrum,
            Chain.optimism.id:      .optimism,
        ]
#if DEBUG
        chains.updateValue(.goerli, forKey: Chain.goerli.id, insertingAt: 1)
#endif
        return chains
    }()
    
    static let defaultChain: Chain = .ethereum
    
}

// MARK: - WalletConnect Request
extension WalletConnectService {
    
    @MainActor
    private func show(proposal: WalletConnectSign.Session.Proposal) {
        connectionHud?.hide()
        guard let container = UIApplication.homeContainerViewController else {
            Task {
                try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .userRejected)
            }
            return
        }
        logger.info(category: "WalletConnectService", message: "Showing: \(proposal))")
        
        var chains = Self.supportedChains.values.map(\.caip2)
        chains.removeAll { chain in
            let isRequired = proposal.requiredNamespaces.values.contains { namespace in
                namespace.chains?.contains(chain) ?? false
            }
            let isOptional: Bool
            if let namespaces = proposal.optionalNamespaces {
                isOptional = namespaces.values.contains { namespace in
                    namespace.chains?.contains(chain) ?? false
                }
            } else {
                isOptional = false
            }
            return !isRequired && !isOptional
        }
        guard !chains.isEmpty else {
            logger.warn(category: "WalletConnectService", message: "Requires to support \(proposal.requiredNamespaces.values.compactMap(\.chains).flatMap { $0 })")
            let requiredChains = proposal.requiredNamespaces.values
                .flatMap { namespace in
                    namespace.chains ?? []
                }
                .map(\.namespace)
            let requiredNamespaces: String
            if requiredChains.isEmpty {
                requiredNamespaces = "<empty>"
            } else {
                requiredNamespaces = requiredChains.joined(separator: ", ")
            }
            presentRejection(title: "Chain not supported", message: "\(proposal.proposer.name) requires to support \(requiredNamespaces)")
            Task {
                try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .unsupportedChains)
            }
            return
        }
        
        let events: Set<String> = ["accountsChanged", "chainChanged"]
        let proposalEvents = proposal.requiredNamespaces.values.map(\.events).flatMap({ $0 })
        guard events.isSuperset(of: proposalEvents) else {
            logger.warn(category: "WalletConnectService", message: "Requires to support \(proposalEvents)")
            presentRejection(title: "Chain not supported", message: "\(proposal.proposer.name) requires to support \(proposalEvents.joined(separator: ", "))")
            Task {
                try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .upsupportedEvents)
            }
            return
        }
        
        let connectWallet = ConnectWalletViewController(info: .walletConnect(proposal))
        connectWallet.onApprove = { priv in
            Task {
                let approvalError: Swift.Error?
                do {
                    let keyStorage = InPlaceKeyStorage(raw: priv)
                    let ethAddress = try EthereumAccount(keyStorage: keyStorage).address.toChecksumAddress()
                    let accounts = chains.compactMap { chain in
                        WalletConnectUtils.Account(blockchain: chain, address: ethAddress)
                    }
                    let sessionNamespaces = try AutoNamespaces.build(sessionProposal: proposal,
                                                                     chains: chains,
                                                                     methods: WalletConnectSession.Method.allCases.map(\.rawValue),
                                                                     events: Array(events),
                                                                     accounts: accounts)
                    try await Web3Wallet.instance.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                    approvalError = nil
                } catch {
                    logger.warn(category: "WalletConnectService", message: "Failed to approve: \(error)")
                    approvalError = error
                    try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .userRejected)
                }
                await MainActor.run {
                    if let error = approvalError {
                        self.presentRejection(title: "Connection Failed", message: error.localizedDescription)
                    } else {
                        let hud = self.loadHud()
                        hud.show(style: .notification, text: R.string.localizable.connected(), on: container.view)
                        hud.scheduleAutoHidden()
                    }
                }
            }
        }
        connectWallet.onReject = {
            Task {
                logger.debug(category: "WalletConnectService", message: "Will reject proposal: \(proposal.id)")
                try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .userRejected)
            }
        }
        let authentication = AuthenticationViewController(intent: connectWallet)
        presentRequest(viewController: authentication)
    }
    
    private func handle(request: WalletConnectSign.Request) {
        DispatchQueue.main.async {
            let topic = request.topic
            if let session = self.sessions.first(where: { $0.topic == topic }) {
                session.handle(request: request)
            } else {
                logger.warn(category: "WalletConnectService", message: "Missing session for topic: \(topic)")
                Task {
                    let error = JSONRPCError(code: -1, message: "Missing session")
                    try await Web3Wallet.instance.respond(topic: topic, requestId: request.id, response: .error(error))
                }
                self.presentRejection(title: R.string.localizable.request_rejected(),
                                      message: R.string.localizable.session_not_found())
            }
        }
    }
    
}
