import Foundation
import BigInt
import web3
import Web3Wallet
import MixinServices

final class WalletConnectV2Session {
    
    enum Error: Swift.Error {
        case invalidParameters
        case mismatchedNamespaces
        case noTransaction
        case noChain(String)
    }
    
    enum Method: String, CaseIterable {
        case personalSign = "personal_sign"
        case ethSignTypedData = "eth_signTypedData"
        case ethSendTransaction = "eth_sendTransaction"
    }
    
    private let session: WalletConnectSign.Session
    
    init(session: WalletConnectSign.Session) {
        self.session = session
    }
    
}

extension WalletConnectV2Session: WalletConnectSession {
    
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
    
    func disconnect() async throws {
        try await Web3Wallet.instance.disconnect(topic: session.topic)
    }
    
    @MainActor
    func handle(request: Request) {
        switch Method(rawValue: request.method) {
        case .personalSign:
            requestPersonalSign(with: request)
        case .ethSignTypedData:
            requestETHSignTypedData(with: request)
        case .ethSendTransaction:
            requestSendTransaction(with: request)
        case .none:
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.method_not_supported(request.method))
            Logger.walletConnect.warn(category: "WalletConnectV2Session", message: "Unknown method: \(request.method)")
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic,
                                                      requestId: request.id,
                                                      response: .error(.init(code: 0, message: "Unsupported method")))
            }
        }
    }
    
}

extension WalletConnectV2Session {
    
    @MainActor
    private func requestPersonalSign(with request: Request) {
        requestSigning(with: request) { request in
            let params = try request.params.get([String].self)
            guard params.count == 2 else {
                throw Error.invalidParameters
            }
            let address = params[1]
            let messageString = params[0]
            let message = try WalletConnectMessage.personalSign(string: messageString)
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
                                                  gasLimit: transactionPreview.gas,
                                                  chainId: chain.id)
            }
            transactionRequest.onSend = {
                let client = Self.makeEthereumClient(with: chain)
                if let account, let transaction {
                    Logger.walletConnect.debug(category: "WalletConnectV2Session", message: "Will send raw tx: \(transaction.jsonRepresentation ?? "(null)")")
                    let hash = try await client.eth_sendRawTransaction(transaction, withAccount: account)
                    let response = RPCResult.response(AnyCodable(hash))
                    try await Web3Wallet.instance.respond(topic: request.topic,
                                                          requestId: request.id,
                                                          response: response)
                } else {
                    Logger.walletConnect.debug(category: "WalletConnectV2Session", message: "Missing variable")
                    assertionFailure()
                }
            }
            
            let authentication = AuthenticationViewController(intentViewController: transactionRequest)
            WalletConnectService.shared.presentRequest(viewController: authentication)
        } catch {
            Logger.walletConnect.debug(category: "WalletConnectV2Session", message: "Failed to send transaction: \(error)")
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.unable_to_decode_the_request(error.localizedDescription))
            Task {
                let error = JSONRPCError(code: 0, message: "Local failed")
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        }
    }
    
}
