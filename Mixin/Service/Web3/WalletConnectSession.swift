import Foundation
import BigInt
import Web3Wallet
import MixinServices

final class WalletConnectSession {
    
    enum Error: Swift.Error {
        case invalidParameters
        case mismatchedNamespaces
        case noTransaction
        case noChain(String)
        case noAccount
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
        session.peer.icons.lazy
            .compactMap(URL.init(string:))
            .first
    }
    
    var name: String {
        session.peer.name
    }
    
    var url: URL? {
        URL(string: session.peer.url)
    }
    
    var host: String {
        url?.host ?? session.peer.url
    }
    
    private let session: WalletConnectSign.Session
    
    init(session: WalletConnectSign.Session) {
        self.session = session
    }
    
    func disconnect() async throws {
        try await Web3Wallet.instance.disconnect(topic: session.topic)
    }
    
    func handle(request: Request) {
        assert(Thread.isMainThread)
        switch Method(rawValue: request.method) {
        case .personalSign:
            requestPersonalSign(with: request)
        case .ethSign:
            rejectETHSign(with: request)
        case .ethSignTypedData, .ethSignTypedDataV4:
            requestETHSignTypedData(with: request)
        case .ethSignTransaction:
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.method_not_supported(request.method)
            Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
            Logger.web3.warn(category: "Session", message: "eth_signTransaction rejected")
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic,
                                                      requestId: request.id,
                                                      response: .error(.init(code: 0, message: "Unsupported method")))
            }
        case .ethSendTransaction:
            requestSendTransaction(with: request)
        case .none:
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.method_not_supported(request.method)
            Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
            Logger.web3.warn(category: "Session", message: "Unknown method: \(request.method)")
            Task {
                try await Web3Wallet.instance.respond(topic: request.topic,
                                                      requestId: request.id,
                                                      response: .error(.init(code: 0, message: "Unsupported method")))
            }
        }
    }
    
}

extension WalletConnectSession {
    
    private func requestPersonalSign(with request: Request) {
        assert(Thread.isMainThread)
        requestSigning(with: request) { request in
            try WalletConnectDecodedSigningRequest.personalSign(request: request)
        }
    }
    
    private func rejectETHSign(with request: Request) {
        assert(Thread.isMainThread)
        Task {
            try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(.methodNotFound))
        }
        let title = R.string.localizable.request_rejected()
        let message = R.string.localizable.method_not_supported(request.method)
        Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
    }
    
    private func requestETHSignTypedData(with request: Request) {
        assert(Thread.isMainThread)
        requestSigning(with: request) { request in
            try WalletConnectDecodedSigningRequest.signTypedData(request: request)
        }
    }
    
    private func requestSendTransaction(with request: Request) {
        assert(Thread.isMainThread)
        let proposer = Web3DappProposer(name: name, host: host)
        DispatchQueue.global().async {
            Logger.web3.info(category: "Session", message: "Got tx: \(request.id) \(request.params)")
            do {
                let params = try request.params.get([Web3TransactionPreview].self)
                guard let transactionPreview = params.first else {
                    throw Error.noTransaction
                }
                guard let chain = Web3Chain.chain(caip2: request.chainId) else {
                    throw Error.noChain(request.chainId.absoluteString)
                }
                // TODO: Get account by `chain`
                guard let address: String = PropertiesDAO.shared.value(forKey: .evmAddress) else {
                    throw Error.noAccount
                }
                let operation = try Web3TransferWithWalletConnectOperation(
                    fromAddress: address,
                    transaction: transactionPreview,
                    chain: chain,
                    session: self,
                    request: request
                )
                DispatchQueue.main.async {
                    let transaction = Web3TransactionViewController(operation: operation, proposer: .dapp(proposer))
                    Web3PopupCoordinator.enqueue(popup: .request(transaction))
                }
            } catch {
                Logger.web3.error(category: "Session", message: "Failed to request tx: \(error)")
                DispatchQueue.main.async {
                    let title = R.string.localizable.request_rejected()
                    let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
                    Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
                }
                Task {
                    let error = JSONRPCError(code: 0, message: "Local failed")
                    try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
                }
            }
        }
    }
    
    private func requestSigning(
        with request: WalletConnectSign.Request,
        decode: (WalletConnectSign.Request) throws -> (WalletConnectDecodedSigningRequest)
    ) {
        assert(Thread.isMainThread)
        do {
            let decoded = try decode(request)
            // TODO: Get account by `request.chainId`
            guard let address: String = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress) else {
                throw Error.noAccount
            }
            let operation = Web3SignWithWalletConnectOperation(address: address, session: self, request: decoded)
            let signRequest = Web3SignViewController(operation: operation, chainName: decoded.chain.name)
            Web3PopupCoordinator.enqueue(popup: .request(signRequest))
        } catch {
            Logger.web3.error(category: "Session", message: "Failed to sign: \(error)")
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
            Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
            Task {
                let error = JSONRPCError(code: 0, message: error.localizedDescription)
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        }
    }
    
}
