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
            rejectETHSign(with: request)
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
            try WalletConnectDecodedSigningRequest.personalSign(request: request)
        }
    }
    
    @MainActor
    private func rejectETHSign(with request: Request) {
        Task {
            try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(.methodNotFound))
        }
        WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                     message: R.string.localizable.method_not_supported(request.method))
    }
    
    @MainActor
    private func requestETHSignTypedData(with request: Request) {
        requestSigning(with: request) { request in
            try WalletConnectDecodedSigningRequest.signTypedData(request: request)
        }
    }
    
    @MainActor
    private func requestSendTransaction(with request: Request) {
        do {
            let params = try request.params.get([WalletConnectTransactionPreview].self)
            guard let transactionPreview = params.first else {
                throw Error.noTransaction
            }
            guard let chain = WalletConnectService.supportedChains[request.chainId] else {
                throw Error.noChain(request.chainId.absoluteString)
            }
            let transactionRequest = TransactionRequestViewController(session: self, request: request, chain: chain, transaction: transactionPreview)
            WalletConnectService.shared.presentRequest(viewController: transactionRequest)
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
    
    @MainActor
    private func requestSigning(
        with request: WalletConnectSign.Request,
        decode: (WalletConnectSign.Request) throws -> (WalletConnectDecodedSigningRequest)
    ) {
        do {
            let decoded = try decode(request)
            let signRequest = SignRequestViewController(session: self, request: decoded)
            WalletConnectService.shared.presentRequest(viewController: signRequest)
        } catch {
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
            WalletConnectService.shared.presentRejection(title: title, message: message)
            Task {
                let error = JSONRPCError(code: 0, message: error.localizedDescription)
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        }
    }
    
}
