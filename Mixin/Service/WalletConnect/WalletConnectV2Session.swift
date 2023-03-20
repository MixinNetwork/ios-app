import Foundation
import BigInt
import web3
import Web3Wallet
import MixinServices

final class WalletConnectV2Session {
    
    enum Error: Swift.Error {
        case invalidParameters
        case mismatchedNamespaces
    }
    
    private enum Method: String, CaseIterable {
        case personalSign = "personal_sign"
        case ethSignTypedData = "eth_signTypedData"
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
        case .none:
            WalletConnectService.shared.presentRejection(title: R.string.localizable.request_rejected(),
                                                         message: R.string.localizable.method_not_supported(request.method))
            Logger.walletConnect.warn(category: "WalletConnectService", message: "Unknown method: \(request.method)")
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
    
}
