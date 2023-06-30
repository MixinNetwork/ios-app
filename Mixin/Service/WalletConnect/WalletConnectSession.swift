import Foundation
import BigInt
import web3
import Web3Wallet
import MixinServices

final class WalletConnectSession {
    
    enum Error: Swift.Error {
        case invalidParameters
        case mismatchedNamespaces
        case noTransaction
        case noChain(String)
    }
    
    enum Method: String, CaseIterable {
        case personalSign = "personal_sign"
        case ethSign = "eth_sign"
        case ethSignTypedData = "eth_signTypedData"
        case ethSignTypedDataV4 = "eth_signTypedData_v4"
        case ethSignTransaction = "eth_signTransaction"
        case ethSendTransaction = "eth_sendTransaction"
    }
    
    var topic: String {
        session.topic
    }
    
    var iconURL: URL? {
        if let icon = session.peer.icons.first {
            return URL(string: icon)
        } else {
            return nil
        }
    }
    
    var name: String {
        session.peer.name
    }
    
    var description: String? {
        session.peer.description
    }
    
    var host: String {
        URL(string: session.peer.url)?.host ?? session.peer.url
    }
    
    private let session: WalletConnectSign.Session
    
    init(session: WalletConnectSign.Session) {
        self.session = session
    }
    
    func disconnect() async throws {
        try await Web3Wallet.instance.disconnect(topic: session.topic)
    }
    
    @MainActor
    func handle(request: Request) {
        switch Method(rawValue: request.method) {
        case .personalSign:
            requestPersonalSign(with: request)
        case .ethSign:
            requestETHSign(with: request)
        case .ethSignTypedData, .ethSignTypedDataV4:
            requestETHSignTypedData(with: request)
        case .ethSignTransaction:
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.method_not_supported(request.method))
            Logger.walletConnect.warn(category: "WalletConnectSession", message: "eth_signTransaction rejected")
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic,
                                                      requestId: request.id,
                                                      response: .error(.init(code: 0, message: "Unsupported method")))
            }
        case .ethSendTransaction:
            requestSendTransaction(with: request)
        case .none:
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.method_not_supported(request.method))
            Logger.walletConnect.warn(category: "WalletConnectSession", message: "Unknown method: \(request.method)")
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic,
                                                      requestId: request.id,
                                                      response: .error(.init(code: 0, message: "Unsupported method")))
            }
        }
    }
    
}

extension WalletConnectSession {
    
    @MainActor
    private func requestPersonalSign(with request: Request) {
        requestSigning(with: request) { request in
            let params = try request.params.get([String].self)
            guard params.count == 2 else {
                throw Error.invalidParameters
            }
            let address = params[1]
            let messageString = params[0]
            let message = try WalletConnectMessage.message(string: messageString)
            return (message: message, address: address)
        } reject: { reason in
            Task {
                let error = JSONRPCError(code: 0, message: reason.description)
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        } approve: { (message, account) in
            let signature = try account.signMessage(message: message.signable)
            let response = RPCResult.response(AnyCodable(signature))
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: response)
            }
        }
    }
    
    @MainActor
    private func requestETHSign(with request: Request) {
        requestSigning(with: request) { request in
            let params = try request.params.get([String].self)
            guard params.count == 2 else {
                throw Error.invalidParameters
            }
            let address = params[0]
            let messageString = params[1]
            let message = try WalletConnectMessage.message(string: messageString)
            return (message: message, address: address)
        } reject: { reason in
            Task {
                let error = JSONRPCError(code: 0, message: reason.description)
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        } approve: { (message, account) in
            let signature = try account.signMessage(message: message.signable)
            let response = RPCResult.response(AnyCodable(signature))
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: response)
            }
        }
    }
    
    @MainActor
    private func requestETHSignTypedData(with request: Request) {
        requestSigning(with: request) { request in
            let params = try request.params.get([String].self)
            guard params.count == 2 else {
                throw Error.invalidParameters
            }
            let address = params[0]
            let messageString = params[1]
            let message = try WalletConnectMessage.typedData(string: messageString)
            return (message: message, address: address)
        } reject: { reason in
            Task {
                let error = JSONRPCError(code: 0, message: reason.description)
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        } approve: { (message, account) in
            let signature = try account.signMessage(message: message.signable)
            let response = RPCResult.response(AnyCodable(signature))
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic,
                                                      requestId: request.id,
                                                      response: response)
            }
        }
    }
    
    @MainActor
    private func requestSendTransaction(with request: Request) {
        do {
            let params = try request.params.get([WalletConnectTransactionPreview].self)
            guard let transactionPreview = params.first else {
                throw Error.noTransaction
            }
            let chain = WalletConnectService.supportedChains.values.first { chain in
                chain.caip2 == request.chainId
            }
            guard let chain else {
                throw Error.noChain(request.chainId.absoluteString)
            }
            let transactionRequest = TransactionRequestViewController(requester: .walletConnect(self),
                                                                      chain: chain,
                                                                      transaction: transactionPreview)
            var account: EthereumAccount?
            var transaction: EthereumTransaction?
            transactionRequest.onReject = {
                Task {
                    let error = JSONRPCError(code: 0, message: "User rejected")
                    try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
                }
            }
            transactionRequest.onApprove = { [unowned transactionRequest] priv in
                let storage = InPlaceKeyStorage(raw: priv)
                account = try EthereumAccount(keyStorage: storage)
                guard
                    transactionPreview.from == account?.address,
                    let fee = transactionRequest.selectedFeeOption
                else {
                    Task {
                        let error = JSONRPCError(code: 0, message: "Address mismatch")
                        try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
                    }
                    return
                }
                transaction = EthereumTransaction(from: nil,
                                                  to: transactionPreview.to,
                                                  value: transactionPreview.value,
                                                  data: transactionPreview.data,
                                                  nonce: nil,
                                                  gasPrice: fee.gasPrice,
                                                  gasLimit: fee.gasLimit,
                                                  chainId: chain.id)
            }
            transactionRequest.onSend = {
                let client = Self.makeEthereumClient(with: chain)
                if let account, let transaction {
                    Logger.walletConnect.debug(category: "WalletConnectSession", message: "Will send raw tx: \(transaction.jsonRepresentation ?? "(null)")")
                    let hash = try await client.eth_sendRawTransaction(transaction, withAccount: account)
                    Logger.walletConnect.debug(category: "WalletConnectService", message: "Will respond hash: \(hash)")
                    let response = RPCResult.response(AnyCodable(hash))
                    try await Web3Wallet.instance.respond(topic: request.topic,
                                                          requestId: request.id,
                                                          response: response)
                } else {
                    Logger.walletConnect.debug(category: "WalletConnectSession", message: "Missing variable")
                    assertionFailure()
                }
            }
            
            let authentication = AuthenticationViewController(intentViewController: transactionRequest)
            WalletConnectService.shared.presentRequest(viewController: authentication)
        } catch {
            Logger.walletConnect.debug(category: "WalletConnectSession", message: "Failed to send transaction: \(error)")
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.unable_to_decode_the_request(error.localizedDescription))
            Task {
                let error = JSONRPCError(code: 0, message: "Local failed")
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        }
    }
    
}

extension WalletConnectSession {
    
    private static func makeEthereumClient(with chain: WalletConnectService.Chain) -> EthereumHttpClient {
        let network: EthereumNetwork
        switch chain {
        case .ethereum:
            network = .mainnet
        case .goerli:
            network = .goerli
        default:
            network = .custom("\(chain.id)")
        }
        Logger.walletConnect.info(category: "WalletConnectSession", message: "New client with: \(chain)")
        return EthereumHttpClient(url: chain.rpcServerURL, network: network)
    }
    
    @MainActor
    private func requestSigning<Request, Signable>(
        with request: Request,
        decodeContent: (Request) throws -> (message: WalletConnectMessage<Signable>, address: String),
        reject: @escaping (WalletConnectRejectionReason) -> Void,
        approve: @escaping (WalletConnectMessage<Signable>, EthereumAccount) throws -> Void
    ) {
        do {
            let (message, address) = try decodeContent(request)
            let signRequest = SignRequestViewController(requester: .walletConnect(self), message: message.humanReadable)
            signRequest.onReject = {
                reject(.userRejected)
            }
            signRequest.onApprove = { priv in
                let storage = InPlaceKeyStorage(raw: priv)
                let account = try EthereumAccount(keyStorage: storage)
                guard address.lowercased() == account.address.asString() else {
                    reject(.mismatchedAddress)
                    return
                }
                try approve(message, account)
            }
            let authentication = AuthenticationViewController(intentViewController: signRequest)
            WalletConnectService.shared.presentRequest(viewController: authentication)
        } catch {
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
            WalletConnectService.shared.presentRejection(title: title, message: message)
            reject(.exception(error))
        }
    }
    
}
