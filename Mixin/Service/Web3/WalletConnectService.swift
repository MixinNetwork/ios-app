import Foundation
import Combine
import OrderedCollections
import BigInt
import ReownWalletKit
import MixinServices

fileprivate var logger: MixinServices.Logger {
    .web3
}

final class WalletConnectService {
    
    static let shared = WalletConnectService()
    
    @Published
    private(set) var sessions: [WalletConnectSession] = []
    
    private let walletDescription = "An open source cryptocurrency wallet with Signal messaging. Fully non-custodial and recoverable with phone number and TIP."
    
    private weak var connectionHud: Hud?
    
    private var subscribes = Set<AnyCancellable>()
    
    private init() {
        Networking.configure(
            groupIdentifier: appGroupIdentifier,
            projectId: MixinKeys.walletConnect,
            socketFactory: StarscreamFactory()
        )
        let metadata = AppMetadata(
            name: .mixin,
            description: walletDescription,
            url: URL.mixinMessenger.absoluteString,
            icons: [],
            redirect: try! .init(native: "mixin://", universal: nil)
        )
        WalletKit.configure(metadata: metadata, crypto: Web3CryptoProvider())
        WalletKit.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.reloadSessions(sessions: sessions)
            }
            .store(in: &subscribes)
        WalletKit.instance.sessionProposalPublisher
            .sink { [weak self] (proposal, context) in
                DispatchQueue.main.async {
                    self?.show(proposal: proposal)
                }
            }
            .store(in: &subscribes)
        WalletKit.instance.sessionRequestPublisher
            .sink { [weak self] (request, context) in
                self?.handle(request: request)
            }
            .store(in: &subscribes)
    }
    
    func reloadSessions() {
        let sessions = Sign.instance.getSessions()
        reloadSessions(sessions: sessions)
    }
    
    func updateSessions(with wallet: Web3Wallet) {
        Task.detached { [sessions] in
            for session in sessions {
                let addresses = Web3AddressDAO.shared.addresses(walletID: wallet.walletID)
                let namespaces = try await session.updatedNamespaces(addresses: addresses)
                do {
                    try await Sign.instance.update(topic: session.topic, namespaces: namespaces)
                } catch {
                    logger.error(category: "Service", message: "Update: \(error)")
                }
            }
        }
    }
    
    func connect(to uri: WalletConnectURI) {
        logger.info(category: "Service", message: "Will connect to v2 topic: \(uri.topic)")
        assert(Thread.isMainThread)
        let hud = loadHud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Task {
            do {
                try await WalletKit.instance.pair(uri: uri)
                logger.info(category: "Serivce", message: "Finished pairing to: \(uri.topic)")
                try await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
                await MainActor.run {
                    guard let hud = self.connectionHud else {
                        return
                    }
                    hud.set(style: .error, text: R.string.localizable.validation_timed_out())
                    hud.scheduleAutoHidden()
                    self.connectionHud = nil
                }
            } catch {
                logger.error(category: "Service", message: "Failed to connect to: \(uri.absoluteString), error: \(error)")
                await MainActor.run {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                    self.connectionHud = nil
                }
            }
        }
    }
    
    func disconnectAllSessions() {
        Task { [sessions] in
            for session in sessions {
                try? await session.disconnect()
            }
        }
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

// MARK: - WalletConnect Request
extension WalletConnectService {
    
    private func show(proposal: WalletConnectSign.Session.Proposal) {
        connectionHud?.hide()
        connectionHud = nil
        DispatchQueue.global().async {
            guard let wallet = Web3WalletDAO.shared.currentSelectedWallet() else {
                Task {
                    try await WalletKit.instance.rejectSession(
                        proposalId: proposal.id,
                        reason: .unsupportedAccounts
                    )
                }
                return
            }
            let walletAddresses = Web3AddressDAO.shared.addresses(walletID: wallet.walletID)
            let addresses: [Web3Chain: Web3Address] = walletAddresses
                .reduce(into: [:]) { result, address in
                    guard let chain = Web3Chain.chain(chainID: address.chainID) else {
                        return
                    }
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
                    if isRequired || isOptional {
                        result[chain] = address
                    }
                }
            guard !addresses.isEmpty else {
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
                    let title = "Chain not supported"
                    let message = "\(proposal.proposer.name) requires to support \(requiredNamespaces)"
                    Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
                }
                Task {
                    try await WalletKit.instance.rejectSession(
                        proposalId: proposal.id,
                        reason: .unsupportedChains
                    )
                }
                return
            }
            
            let events: Set<String> = ["connect", "disconnect", "chainChanged", "accountsChanged", "message"]
            let proposalEvents = proposal.requiredNamespaces.values.map(\.events).flatMap({ $0 })
            guard events.isSuperset(of: proposalEvents) else {
                logger.warn(category: "Service", message: "Requires to support \(proposalEvents)")
                let events = proposalEvents.joined(separator: ", ")
                DispatchQueue.main.async {
                    let title = "Chain not supported"
                    let message = "\(proposal.proposer.name) requires to support \(events)"
                    Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
                }
                Task {
                    try await WalletKit.instance.rejectSession(
                        proposalId: proposal.id,
                        reason: .unsupportedEvents
                    )
                }
                return
            }
            DispatchQueue.main.async {
                let connectWallet = ConnectWalletViewController(
                    wallet: wallet,
                    addresses: addresses,
                    proposal: proposal,
                    events: Array(events)
                )
                Web3PopupCoordinator.enqueue(popup: .request(connectWallet))
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
                    try await WalletKit.instance.respond(topic: topic, requestId: request.id, response: .error(error))
                }
                let title = R.string.localizable.request_rejected()
                let message = R.string.localizable.session_not_found()
                Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
            }
        }
    }
    
}
