import Foundation
import Combine
import OrderedCollections
import BigInt
import web3
import Web3Wallet
import MixinServices

fileprivate var logger: MixinServices.Logger {
    .web3
}

final class WalletConnectService {
    
    static let shared = WalletConnectService()
    
    static var isAvailable: Bool {
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
                self?.reloadSessions(sessions: sessions)
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
        let sessions = Sign.instance.getSessions()
        reloadSessions(sessions: sessions)
    }
    
    func connect(to uri: WalletConnectURI) {
        logger.debug(category: "Service", message: "Will connect to v2 topic: \(uri.topic)")
        assert(Thread.isMainThread)
        let hud = loadHud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Task {
            do {
                try await Web3Wallet.instance.pair(uri: uri)
                logger.info(category: "Serivce", message: "Finished pairing to: \(uri.topic)")
            } catch {
                logger.error(category: "Service", message: "Failed to connect to: \(uri.absoluteString), error: \(error)")
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
    
    private func reloadSessions(sessions: [WalletConnectSign.Session]) {
        self.sessions = sessions.map(WalletConnectSession.init(session:))
        let topics = self.sessions.map(\.topic)
        Task {
            do {
                try await Relay.instance.batchSubscribe(topics: topics)
            } catch {
                logger.error(category: "Service", message: "Failed to subscribe: \(error)")
            }
        }
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
    
    struct Chain: Equatable, Hashable {
        
        static let ethereum = Chain(
            id: 1,
            internalID: ChainID.ethereum,
            name: "Ethereum",
            rpcServerURL: URL(string: "https://cloudflare-eth.com")!,
            feeSymbol: "ETH",
            caip2: Blockchain("eip155:1")!
        )
        
        static let polygon = Chain(
            id: 137,
            internalID: ChainID.polygon,
            name: "Polygon",
            rpcServerURL: URL(string: "https://polygon-rpc.com")!,
            feeSymbol: "MATIC",
            caip2: Blockchain("eip155:137")!
        )
        
        static let bnbSmartChain = Chain(
            id: 56,
            internalID: ChainID.bnbSmartChain,
            name: "BSC",
            rpcServerURL: URL(string: "https://endpoints.omniatech.io/v1/bsc/mainnet/public")!,
            feeSymbol: "BNB",
            caip2: Blockchain("eip155:56")!
        )
        
        static let sepolia = Chain(
            id: 11155111,
            internalID: ChainID.ethereum,
            name: "Sepolia",
            rpcServerURL: URL(string: "https://rpc.sepolia.dev")!,
            feeSymbol: "ETH",
            caip2: Blockchain("eip155:11155111")!
        )
        
        let id: Int
        let internalID: String
        let name: String
        let rpcServerURL: URL
        let feeSymbol: String
        let caip2: Blockchain
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        func makeEthereumClient() -> EthereumHttpClient {
            let network: EthereumNetwork = switch self {
            case .ethereum:
                    .mainnet
            case .sepolia:
                    .sepolia
            default:
                    .custom("\(id)")
            }
            return EthereumHttpClient(url: rpcServerURL, network: network)
        }
        
    }
    
    static let supportedChains: OrderedDictionary<Blockchain, Chain> = {
        var chains: OrderedDictionary<Blockchain, Chain> = [
            Chain.ethereum.caip2:      .ethereum,
            Chain.polygon.caip2:       .polygon,
            Chain.bnbSmartChain.caip2: .bnbSmartChain,
        ]
#if DEBUG
        chains.updateValue(.sepolia, forKey: Chain.sepolia.caip2, insertingAt: 1)
#endif
        return chains
    }()
    
    static let evmChains: OrderedSet<Chain> = [.ethereum, .polygon, .bnbSmartChain]
    
    static let defaultChain: Chain = .ethereum
    
}

// MARK: - WalletConnect Request
extension WalletConnectService {
    
    private func show(proposal: WalletConnectSign.Session.Proposal) {
        connectionHud?.hide()
        DispatchQueue.global().async {
            var chains = Array(Self.supportedChains.values)
            chains.removeAll { chain in
                let isRequired = proposal.requiredNamespaces.values.contains { namespace in
                    namespace.chains?.contains(chain.caip2) ?? false
                }
                let isOptional: Bool
                if let namespaces = proposal.optionalNamespaces {
                    isOptional = namespaces.values.contains { namespace in
                        namespace.chains?.contains(chain.caip2) ?? false
                    }
                } else {
                    isOptional = false
                }
                return !isRequired && !isOptional
            }
            guard !chains.isEmpty else {
                logger.warn(category: "Service", message: "Requires to support \(proposal.requiredNamespaces.values.compactMap(\.chains).flatMap { $0 })")
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
                DispatchQueue.main.async {
                    self.presentRejection(title: "Chain not supported",
                                          message: "\(proposal.proposer.name) requires to support \(requiredNamespaces)")
                }
                Task {
                    try await Web3Wallet.instance.rejectSession(proposalId: proposal.id, reason: .unsupportedChains)
                }
                return
            }
            
            let events: Set<String> = ["accountsChanged", "chainChanged"]
            let proposalEvents = proposal.requiredNamespaces.values.map(\.events).flatMap({ $0 })
            guard events.isSuperset(of: proposalEvents) else {
                logger.warn(category: "Service", message: "Requires to support \(proposalEvents)")
                let events = proposalEvents.joined(separator: ", ")
                DispatchQueue.main.async {
                    self.presentRejection(title: "Chain not supported",
                                          message: "\(proposal.proposer.name) requires to support \(events))")
                }
                Task {
                    try await Web3Wallet.instance.rejectSession(proposalId: proposal.id, reason: .upsupportedEvents)
                }
                return
            }
            
            let account: String? = PropertiesDAO.shared.value(forKey: .evmAccount)
            if account == nil {
                DispatchQueue.main.async {
                    let unlock = UnlockWeb3WalletViewController(chain: chains[0])
                    unlock.onDismiss = { isUnlocked in
                        if isUnlocked {
                            self.presentedViewController = nil // Value may not released immediately
                            let connectWallet = ConnectWalletViewController(proposal: proposal,
                                                                            chains: chains.map(\.caip2),
                                                                            events: Array(events))
                            self.presentRequest(viewController: connectWallet)
                        } else {
                            Task {
                                try await Web3Wallet.instance.rejectSession(proposalId: proposal.id, reason: .userRejected)
                            }
                        }
                    }
                    self.presentRequest(viewController: unlock)
                }
            } else {
                logger.info(category: "Service", message: "Showing: \(proposal))")
                DispatchQueue.main.async {
                    let connectWallet = ConnectWalletViewController(proposal: proposal,
                                                                    chains: chains.map(\.caip2),
                                                                    events: Array(events))
                    self.presentRequest(viewController: connectWallet)
                }
            }
        }
    }
    
    private func handle(request: WalletConnectSign.Request) {
        DispatchQueue.main.async {
            let topic = request.topic
            if let session = self.sessions.first(where: { $0.topic == topic }) {
                session.handle(request: request)
            } else {
                logger.warn(category: "Service", message: "Missing session for topic: \(topic)")
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
