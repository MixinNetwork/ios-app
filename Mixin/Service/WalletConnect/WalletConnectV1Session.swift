import Foundation
import BigInt
import web3
import WalletConnectSwift
import MixinServices

final class WalletConnectV1Session {
    
    enum Error: Swift.Error, LocalizedError {
        
        case invalidParameters
        case noWalletInfo
        case chainNotSupported
        
        var errorDescription: String? {
            switch self {
            case .invalidParameters:
                return "Invalid parameters"
            case .noWalletInfo:
                return "No wallet info"
            case .chainNotSupported:
                return "Chain not supported"
            }
        }
        
    }
    
    enum Method: String, CaseIterable {
        case walletSwitchEthereumChain = "wallet_switchEthereumChain"
        case personalSign = "personal_sign"
        case ethSignTypedData = "eth_signTypedData"
        case sendTransaction = "eth_sendTransaction"
    }
    
    static let didUpdateNotification = Notification.Name("one.mixin.messenger.WalletConnectV1Session.DidUpdate")
    
    private let server: Server
    
    private(set) var session: WalletConnectSwift.Session
    private(set) var chain: WalletConnectService.Chain
    
    private lazy var ethereumClient = makeEthereumClient(with: chain)
    
    init(server: Server, chain: WalletConnectService.Chain, session: WalletConnectSwift.Session) {
        self.server = server
        self.chain = chain
        self.session = session
    }
    
    func replace(session: WalletConnectSwift.Session) {
        assert(Thread.isMainThread)
        self.session = session
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
    }
    
    func `switch`(to chain: WalletConnectService.Chain) throws {
        assert(Thread.isMainThread)
        guard let walletInfo = session.walletInfo else {
            throw Error.noWalletInfo
        }
        let info = Session.WalletInfo(approved: true,
                                      accounts: walletInfo.accounts,
                                      chainId: chain.id,
                                      peerId: walletInfo.peerId,
                                      peerMeta: walletInfo.peerMeta)
        try server.updateSession(session, with: info)
        self.session.walletInfo = info
        self.chain = chain
        self.ethereumClient = makeEthereumClient(with: chain)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
    }
    
    private func makeEthereumClient(with chain: WalletConnectService.Chain) -> EthereumHttpClient {
        let network: EthereumNetwork
        switch chain {
        case .ethereum:
            network = .mainnet
        case .goerli:
            network = .goerli
        default:
            network = .custom("\(chain.id)")
        }
        Logger.walletConnect.info(category: "V1Session", message: "New client with: \(chain)")
        return EthereumHttpClient(url: chain.rpcServerURL, network: network)
    }
    
}

extension WalletConnectV1Session: WalletConnectSession {
    
    var topic: String {
        session.url.topic
    }
    
    var iconURL: URL? {
        session.dAppInfo.peerMeta.icons.first
    }
    
    var name: String {
        session.dAppInfo.peerMeta.name
    }
    
    var description: String? {
        session.dAppInfo.peerMeta.description
    }
    
    var host: String {
        session.dAppInfo.peerMeta.url.host ?? session.dAppInfo.peerMeta.url.absoluteString
    }
    
    func disconnect() async throws {
        try server.disconnect(from: session)
    }
    
    @MainActor
    func handle(request: Request) {
        switch Method(rawValue: request.method) {
        case .walletSwitchEthereumChain:
            requestWalletSwitchEthereumChain(with: request)
        case .personalSign:
            requestPersonalSign(with: request)
        case .ethSignTypedData:
            requestETHSignTypedData(with: request)
        case .sendTransaction:
            requestSendTransaction(with: request)
        case .none:
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.method_not_supported(request.method))
            Logger.walletConnect.warn(category: "WalletConnectService", message: "Unknown method: \(request.method)")
            server.send(.reject(request))
        }
    }
    
}

extension WalletConnectV1Session {
    
    @MainActor
    private func requestWalletSwitchEthereumChain(with request: WalletConnectSwift.Request) {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        do {
            let parameters = try request.parameter(of: [String: String].self, at: 0)
            guard let hexChainId = parameters["chainId"], let chainId = Int(hex: hexChainId) else {
                throw Error.invalidParameters
            }
            guard let newChain = WalletConnectService.supportedChains[chainId] else {
                throw Error.chainNotSupported
            }
            let alert = UIAlertController(title: R.string.localizable.switch_network(),
                                          message: R.string.localizable.requests_switching_to_network(name, newChain.name),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.switch_to_network(newChain.name), style: .default, handler: { _ in
                let hud = Hud()
                do {
                    hud.show(style: .busy, text: "", on: container.view)
                    try self.switch(to: newChain)
                    hud.set(style: .notification, text: R.string.localizable.network_switched())
                } catch {
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.keep_network(chain.name), style: .default, handler: { _ in
                self.server.send(.reject(request))
            }))
            container.presentOnTopMostPresentedController(alert, animated: true)
        } catch {
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.failed_to_switch_network(error.localizedDescription))
            server.send(.reject(request))
        }
    }
    
    @MainActor
    private func requestPersonalSign(with request: WalletConnectSwift.Request) {
        requestSigning(with: request) { request in
            let address = try request.parameter(of: String.self, at: 1)
            let messageString = try request.parameter(of: String.self, at: 0)
            let message = try WalletConnectMessage.personalSign(string: messageString)
            return (message: message, address: address)
        } reject: { _ in
            self.server.send(.reject(request))
        } approve: { (message, account) in
            let signature = try account.signMessage(message: message.signable)
            let response = try Response(url: request.url, value: signature, id: request.id!)
            self.server.send(response)
        }
    }
    
    @MainActor
    private func requestETHSignTypedData(with request: WalletConnectSwift.Request) {
        requestSigning(with: request) { request in
            let address = try request.parameter(of: String.self, at: 0)
            let messageString = try request.parameter(of: String.self, at: 1)
            let message = try WalletConnectMessage.typedData(string: messageString)
            return (message: message, address: address)
        } reject: { _ in
            self.server.send(.reject(request))
        } approve: { (message, account) in
            let signature = try account.signMessage(message: message.signable)
            let response = try Response(url: request.url, value: signature, id: request.id!)
            self.server.send(response)
        }
    }
    
    @MainActor
    private func requestSendTransaction(with request: WalletConnectSwift.Request) {
        do {
            let transactionPreview = try request.parameter(of: WalletConnectTransactionPreview.self, at: 0)
            let transactionRequest = TransactionRequestViewController(requester: .walletConnect(self),
                                                                      chain: chain,
                                                                      transaction: transactionPreview)
            var account: EthereumAccount?
            var transaction: EthereumTransaction?
            transactionRequest.onReject = {
                self.server.send(.reject(request))
            }
            transactionRequest.onApprove = { [unowned transactionRequest] priv in
                let storage = InPlaceKeyStorage(raw: priv)
                account = try EthereumAccount(keyStorage: storage)
                guard
                    transactionPreview.from == account?.address,
                    let fee = transactionRequest.selectedFeeOption
                else {
                    self.server.send(.reject(request))
                    return
                }
                transaction = EthereumTransaction(from: nil,
                                                  to: transactionPreview.to,
                                                  value: transactionPreview.value,
                                                  data: transactionPreview.data,
                                                  nonce: nil,
                                                  gasPrice: fee.gasPrice,
                                                  gasLimit: transactionPreview.gas,
                                                  chainId: self.chain.id)
            }
            transactionRequest.onSend = {
                if let account, let transaction {
                    Logger.walletConnect.debug(category: "WalletConnectService", message: "Will send raw tx: \(transaction.jsonRepresentation ?? "(null)")")
                    let hash = try await self.ethereumClient.eth_sendRawTransaction(transaction, withAccount: account)
                    let response = try Response(url: request.url, value: hash, id: request.id!)
                    self.server.send(response)
                } else {
                    Logger.walletConnect.debug(category: "WalletConnectService", message: "Missing variable")
                    assertionFailure()
                }
            }
            
            let authentication = AuthenticationViewController(intentViewController: transactionRequest)
            WalletConnectService.shared.presentRequest(viewController: authentication)
        } catch {
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.unable_to_decode_the_request(error.localizedDescription))
            self.server.send(.reject(request))
        }
    }
    
}
