import Foundation
import Combine
import OrderedCollections
import BigInt
import web3
import Auth
import WalletConnectSwift
import Web3Wallet
import MixinServices

fileprivate var logger: MixinServices.Logger {
    .walletConnect
}

final class WalletConnectService {
    
    static let shared = WalletConnectService()
    
    @Published
    private(set) var v1Sessions: [WalletConnectV1Session] = []
    
    @Published
    private(set) var v2Sessions: [WalletConnectV2Session] = []
    
    private let sessionsStorageKey = "walletconnect_sessions"
    private let walletName = "Mixin Messenger"
    private let walletDescription = "An open source cryptocurrency wallet with Signal messaging. Fully non-custodial and recoverable with phone number and TIP."
    
    private var connectionHud: Hud?
    private var areV1SessionsRestored = false
    private var subscribes = Set<AnyCancellable>()
    
    // Only one request or proposal can be presented at a time
    // New incoming requests will be rejected if `presentedViewController` is not nil
    private weak var presentedViewController: UIViewController?
    
    private lazy var server: Server = {
        let server = Server(delegate: self)
        let handler = RequestHandlerProxy(handler: self)
        server.register(handler: handler)
        return server
    }()
    
    private init() {
        Networking.configure(projectId: MixinKeys.walletConnect,
                             socketFactory: URLSessionWebSocketFactory())
        let meta = AppMetadata(name: walletName,
                               description: walletDescription,
                               url: URL.mixinMessenger.absoluteString,
                               icons: ["https://mixin.one/assets/eccaf16dd38b2210f935.png"])
        Web3Wallet.configure(metadata: meta,
                             signerFactory: Web3SignerFactory())
        Web3Wallet.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.reloadSessions()
            }
            .store(in: &subscribes)
        Web3Wallet.instance.sessionProposalPublisher
            .sink { [weak self] proposal in
                DispatchQueue.main.async {
                    self?.show(proposal: proposal)
                }
            }
            .store(in: &subscribes)
        Web3Wallet.instance.sessionRequestPublisher
            .sink { [weak self] request in
                self?.handle(request: request)
            }
            .store(in: &subscribes)
    }
    
    func connect(to url: WCURL) {
        logger.debug(category: "WalletConnectService", message: "Will connect to v1 topic: \(url.topic)")
        assert(Thread.isMainThread)
        let hud = loadHud()
        do {
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            try server.connect(to: url)
        } catch {
            logger.error(category: "WalletConnectService", message: "Failed to connect to: \(url.absoluteString)")
            hud.set(style: .error, text: error.localizedDescription)
            hud.scheduleAutoHidden()
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
    
    private func firstV1Session(matches topic: String) -> WalletConnectV1Session? {
        v1Sessions.first { session in
            session.topic == topic
        }
    }
    
    private func firstV2Session(matches topic: String) -> WalletConnectV2Session? {
        v2Sessions.first { session in
            session.topic == topic
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
    
    struct Chain: Equatable {
        
        static let ethereum = Chain(
            id: 1,
            internalID: "43d61dcd-e413-450d-80b8-101d5e903357",
            name: "Ethereum",
            rpcServerURL: URL(string: "https://rpc.ankr.com/eth")!,
            gasSymbol: "ETH"
        )
        static let goerli = Chain(
            id: 5,
            internalID: "43d61dcd-e413-450d-80b8-101d5e903357",
            name: "Goerli",
            rpcServerURL: URL(string: "https://rpc.ankr.com/eth_goerli")!,
            gasSymbol: "ETH"
        )
        static let binanceSmartChain = Chain(
            id: 56,
            internalID: "1949e683-6a08-49e2-b087-d6b72398588f",
            name: "Binance Smart Chain",
            rpcServerURL: URL(string: "https://endpoints.omniatech.io/v1/bsc/mainnet/public")!,
            gasSymbol: "BSC"
        )
        static let polygon = Chain(
            id: 137,
            internalID: "b7938396-3f94-4e0a-9179-d3440718156f",
            name: "Polygon",
            rpcServerURL: URL(string: "https://polygon.blockpi.network/v1/rpc/public")!,
            gasSymbol: "MATIC"
        )
        
        let id: Int
        let internalID: String
        let name: String
        let rpcServerURL: URL
        let gasSymbol: String
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
    }
    
    static let supportedChains: OrderedDictionary<Int, Chain> = {
        var chains: OrderedDictionary<Int, Chain> = [
            Chain.ethereum.id:              .ethereum,
            Chain.binanceSmartChain.id:     .binanceSmartChain,
            Chain.polygon.id:               .polygon,
        ]
#if DEBUG
        chains.updateValue(.goerli, forKey: Chain.goerli.id, insertingAt: 1)
#endif
        return chains
    }()
    
    static let defaultChain: Chain = .ethereum
    
}

// MARK: - Session
extension WalletConnectService {
    
    func reloadSessions() {
        if !areV1SessionsRestored, let data = UserDefaults.standard.data(forKey: sessionsStorageKey) {
            do {
                // Session will be appended afterwards in `server(_:, didConnect:)`
                let sessions = try PropertyListDecoder.default.decode([WalletConnectSwift.Session].self, from: data)
                try sessions.forEach(server.reconnect(to:))
            } catch {
                logger.error(category: "WalletConnectService", message: "Failed to restore: \(error)")
            }
            areV1SessionsRestored = true
        }
        self.v2Sessions = Sign.instance.getSessions().map(WalletConnectV2Session.init(session:))
    }
    
    @objc private func saveSessions() {
        // WalletConnect V2 sessions are saved by the SDK
        do {
            let data = try PropertyListEncoder.default.encode(v1Sessions.map(\.session))
            UserDefaults.standard.set(data, forKey: sessionsStorageKey)
        } catch {
            logger.error(category: "WalletConnectService", message: "Unable to encode sessions: \(error)")
        }
    }
    
}

// MARK: - V1 Delegate
extension WalletConnectService: ServerDelegate {
    
    func server(_ server: Server, didFailToConnect url: WCURL) {
        logger.debug(category: "WalletConnectService", message: "Failed connect to: \(url)")
        DispatchQueue.main.async {
            if let hud = self.connectionHud {
                hud.set(style: .error, text: R.string.localizable.connection_failed())
                hud.scheduleAutoHidden()
            }
        }
    }
    
    func server(
        _ server: Server,
        shouldStart session: WalletConnectSwift.Session,
        completion: @escaping (WalletConnectSwift.Session.WalletInfo) -> Void
    ) {
        let chain: Chain
        if let id = session.dAppInfo.chainId, let supportedChain = Self.supportedChains[id] {
            chain = supportedChain
        } else {
            chain = Self.defaultChain
        }
        let meta = WalletConnectSwift.Session.ClientMeta(name: walletName,
                                                         description: walletDescription,
                                                         icons: [],
                                                         url: .mixinMessenger)
        DispatchQueue.main.async {
            self.connectionHud?.hide()
            guard let container = UIApplication.homeContainerViewController else {
                return
            }
            let connectWallet = ConnectWalletViewController(info: .v1(session.dAppInfo.peerMeta, chain))
            connectWallet.onApprove = { priv in
                do {
                    let storage = InPlaceKeyStorage(raw: priv)
                    let account = try EthereumAccount(keyStorage: storage)
                    let info = WalletConnectSwift.Session.WalletInfo(approved: true,
                                                                     accounts: [account.address.toChecksumAddress()],
                                                                     chainId: chain.id,
                                                                     peerId: UUID().uuidString,
                                                                     peerMeta: meta)
                    self.connectionHud?.show(style: .busy, text: "", on: container.view)
                    completion(info)
                } catch {
                    logger.error(category: "WalletConnectService", message: "Failed to start: \(error)")
                    self.connectionHud?.show(style: .error, text: error.localizedDescription, on: container.view)
                    completion(.init(approved: false, accounts: [], chainId: chain.id, peerId: "", peerMeta: meta))
                }
            }
            connectWallet.onReject = {
                completion(.init(approved: false, accounts: [], chainId: chain.id, peerId: "", peerMeta: meta))
            }
            let authentication = AuthenticationViewController(intentViewController: connectWallet)
            self.presentRequest(viewController: authentication)
        }
    }
    
    func server(_ server: Server, didConnect session: WalletConnectSwift.Session) {
        logger.debug(category: "WalletConnectService", message: "Did connect")
        DispatchQueue.main.async {
            let chainId = session.walletInfo?.chainId ?? Self.defaultChain.id
            guard let chain = Self.supportedChains[chainId] else {
                if let hud = self.connectionHud {
                    hud.set(style: .error, text: R.string.localizable.chain_not_supported())
                    hud.scheduleAutoHidden()
                }
                try? self.server.disconnect(from: session)
                logger.debug(category: "WalletConnectService", message: "Disconnected due to unsupported chain: \(chainId)")
                return
            }
            let existedSessionIndex = self.v1Sessions.firstIndex { existedSession in
                existedSession.topic == session.url.topic
            }
            let newSession = WalletConnectV1Session(server: server, chain: chain, session: session)
            if let index = existedSessionIndex {
                self.v1Sessions[index] = newSession
            } else {
                self.v1Sessions.append(newSession)
            }
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(self.saveSessions),
                                                   name: WalletConnectV1Session.didUpdateNotification,
                                                   object: newSession)
            self.saveSessions()
            if let hud = self.connectionHud {
                hud.set(style: .notification, text: R.string.localizable.connected())
                hud.scheduleAutoHidden()
            }
        }
    }
    
    func server(_ server: Server, didDisconnect session: WalletConnectSwift.Session) {
        logger.debug(category: "WalletConnectService", message: "Did disconnect")
        DispatchQueue.main.async {
            self.v1Sessions.removeAll { existedSession in
                if existedSession.topic == session.url.topic {
                    NotificationCenter.default.removeObserver(self,
                                                              name: WalletConnectV1Session.didUpdateNotification,
                                                              object: existedSession)
                    return true
                } else {
                    return false
                }
            }
            self.saveSessions()
        }
    }
    
    func server(_ server: Server, didUpdate session: WalletConnectSwift.Session) {
        logger.debug(category: "WalletConnectService", message: "Did update")
        DispatchQueue.main.async {
            self.firstV1Session(matches: session.url.topic)?.replace(session: session)
        }
    }
    
}

// MARK: - V1 Request
extension WalletConnectService: RequestHandler {
    
    private class RequestHandlerProxy: RequestHandler {
        
        private weak var handler: RequestHandler?
        
        init(handler: RequestHandler) {
            self.handler = handler
        }
        
        func canHandle(request: WalletConnectSwift.Request) -> Bool {
            handler?.canHandle(request: request) ?? false
        }
        
        func handle(request: WalletConnectSwift.Request) {
            handler?.handle(request: request)
        }
        
    }
    
    func canHandle(request: WalletConnectSwift.Request) -> Bool {
        WalletConnectV1Session.Method.allCases.contains { method in
            method.rawValue == request.method
        }
    }
    
    func handle(request: WalletConnectSwift.Request) {
        DispatchQueue.main.async {
            let topic = request.url.topic
            if let session = self.firstV1Session(matches: topic) {
                session.handle(request: request)
            } else {
                logger.warn(category: "WalletConnectService", message: "Missing session for topic: \(topic)")
                self.presentRejection(title: R.string.localizable.request_rejected(),
                                      message: R.string.localizable.session_not_found())
                self.server.send(.reject(request))
            }
        }
    }
    
}

// MARK: - V2 Request
extension WalletConnectService {
    
    @MainActor
    private func show(proposal: WalletConnectSign.Session.Proposal) {
        connectionHud?.hide()
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        let connectWallet = ConnectWalletViewController(info: .v2(proposal))
        connectWallet.onApprove = { priv in
            Task {
                let approvalError: Swift.Error?
                do {
                    let sessionNamespaces = try self.makeSessionNamespaces(for: proposal, with: priv)
                    try await Web3Wallet.instance.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                    approvalError = nil
                } catch {
                    approvalError = error
                }
                await MainActor.run {
                    let hud = self.loadHud()
                    if let error = approvalError {
                        hud.show(style: .error, text: error.localizedDescription, on: container.view)
                    } else {
                        hud.show(style: .notification, text: R.string.localizable.connected(), on: container.view)
                    }
                    hud.scheduleAutoHidden()
                }
            }
        }
        connectWallet.onReject = {
            Task {
                logger.debug(category: "WalletConnectService", message: "Will reject proposal: \(proposal.id)")
                try await Web3Wallet.instance.reject(proposalId: proposal.id, reason: .userRejected)
            }
        }
        let authentication = AuthenticationViewController(intentViewController: connectWallet)
        presentRequest(viewController: authentication)
    }
    
    private func handle(request: WalletConnectSign.Request) {
        DispatchQueue.main.async {
            let topic = request.topic
            if let session = self.firstV2Session(matches: topic) {
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
    
    private func makeSessionNamespaces(for proposal: WalletConnectSign.Session.Proposal, with priv: Data) throws -> [String: SessionNamespace] {
        var proposalNamespaces = proposal.requiredNamespaces
        guard proposalNamespaces.allSatisfy({ $0.key.hasPrefix("eip155") }) else {
            throw WalletConnectV2Session.Error.mismatchedNamespaces
        }
        if let optionalNamespaces = proposal.optionalNamespaces {
            for namespace in optionalNamespaces where namespace.key.hasPrefix("eip155") {
                proposalNamespaces[namespace.key] = namespace.value
            }
        }
        
        let keyStorage = InPlaceKeyStorage(raw: priv)
        let ethAddress = try EthereumAccount(keyStorage: keyStorage).address.toChecksumAddress()
        
        var sessionNamespaces: [String: SessionNamespace] = [:]
        for namespace in proposalNamespaces {
            let caip2Namespace = namespace.key
            let caip2NamespaceComponents = namespace.key.components(separatedBy: ":")
            let proposalNamespace = namespace.value
            var accounts = Set<WalletConnectUtils.Account>()
            if let chains = proposalNamespace.chains {
                accounts = Set(
                    chains.compactMap { chain in
                        WalletConnectUtils.Account(chain.absoluteString + ":" + ethAddress)
                    }
                )
                let sessionNamespace = SessionNamespace(chains: chains, accounts: accounts, methods: proposalNamespace.methods, events: proposalNamespace.events)
                sessionNamespaces[caip2Namespace] = sessionNamespace
            } else if let network = caip2NamespaceComponents.first, let chain = caip2NamespaceComponents.last {
                let accounts: Set<WalletConnectUtils.Account>
                if let account = Account("\(network):\(chain):\(ethAddress)") {
                    accounts = [account]
                } else {
                    accounts = []
                }
                let sessionNamespace = SessionNamespace(accounts: accounts, methods: proposalNamespace.methods, events: proposalNamespace.events)
                sessionNamespaces[namespace.key] = sessionNamespace
            }
        }
        return sessionNamespaces
    }
    
}
