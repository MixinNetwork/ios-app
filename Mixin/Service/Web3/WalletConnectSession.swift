import Foundation
import BigInt
import ReownWalletKit
import MixinServices

final class WalletConnectSession {
    
    enum Error: Swift.Error {
        case invalidParameters
        case mismatchedNamespaces
        case noTransaction
        case noChain(String)
        case noWallet
        case noAddress
    }
    
    enum Method: String, CaseIterable {
        case personalSign = "personal_sign"
        case ethSign = "eth_sign"
        case ethSignTypedData = "eth_signTypedData"
        case ethSignTypedDataV4 = "eth_signTypedData_v4"
        case ethSignTransaction = "eth_signTransaction"
        case ethSendTransaction = "eth_sendTransaction"
        case solanaSignMessage = "solana_signMessage"
        case solanaSignTransaction = "solana_signTransaction"
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
        try await WalletKit.instance.disconnect(topic: session.topic)
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
                try await WalletKit.instance.respond(
                    topic: request.topic,
                    requestId: request.id,
                    response: .error(.init(code: 0, message: "Unsupported method"))
                )
            }
        case .ethSendTransaction:
            requestETHSendTransaction(with: request)
        case .solanaSignMessage:
            requestSolanaSignMessage(with: request)
        case .solanaSignTransaction:
            requestSolanaSignTransaction(with: request)
        case .none:
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.method_not_supported(request.method)
            Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
            Logger.web3.warn(category: "Session", message: "Unknown method: \(request.method)")
            Task {
                try await WalletKit.instance.respond(
                    topic: request.topic,
                    requestId: request.id,
                    response: .error(.init(code: 0, message: "Unsupported method"))
                )
            }
        }
    }
    
    func updatedNamespaces(addresses: [Web3Address]) async throws -> [String: SessionNamespace] {
        let addresses: [Blockchain: String] = addresses.reduce(into: [:]) { result, address in
            if let chain = Web3Chain.chain(chainID: address.chainID) {
                result[chain.caip2] = address.destination
            }
        }
        return session.namespaces.reduce(into: [:]) { (result, pair) in
            var namespace = pair.value
            let newAccounts = namespace.accounts.compactMap { account in
                if let address = addresses[account.blockchain]  {
                    WalletConnectUtils.Account(
                        blockchain: account.blockchain,
                        address: address
                    )
                } else {
                    nil
                }
            }
            if !newAccounts.isEmpty {
                namespace.accounts = newAccounts
                result[pair.key] = namespace
            }
        }
    }
    
}

extension WalletConnectSession {
    
    private func requestPersonalSign(with request: Request) {
        assert(Thread.isMainThread)
        requestSigning(with: request) { request in
            try WalletConnectDecodedSigningRequest.ethPersonalSign(request: request)
        }
    }
    
    private func rejectETHSign(with request: Request) {
        assert(Thread.isMainThread)
        Task {
            try await WalletKit.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(.methodNotFound)
            )
        }
        let title = R.string.localizable.request_rejected()
        let message = R.string.localizable.method_not_supported(request.method)
        Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
    }
    
    private func requestETHSignTypedData(with request: Request) {
        assert(Thread.isMainThread)
        requestSigning(with: request) { request in
            try WalletConnectDecodedSigningRequest.ethSignTypedData(request: request)
        }
    }
    
    private func requestETHSendTransaction(with request: Request) {
        assert(Thread.isMainThread)
        let proposer = Web3DappProposer(name: name, host: host)
        Task.detached {
            Logger.web3.info(category: "Session", message: "Got tx: \(request.id) \(request.params)")
            do {
                let params = try request.params.get([ExternalEVMTransaction].self)
                guard let transactionPreview = params.first else {
                    throw Error.noTransaction
                }
                guard let chain = Web3Chain.chain(caip2: request.chainId) else {
                    throw Error.noChain(request.chainId.absoluteString)
                }
                guard let wallet = Web3WalletDAO.shared.currentSelectedWallet() else {
                    throw Error.noWallet
                }
                guard let address = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chain.chainID) else {
                    throw Error.noAddress
                }
                let operation = try Web3TransferWithWalletConnectOperation(
                    wallet: wallet,
                    fromAddress: address,
                    transaction: transactionPreview,
                    chain: chain,
                    session: self,
                    request: request
                )
                let fee = try await operation.loadFee()
                let feeRequirement = BalanceRequirement(token: operation.feeToken, amount: fee.tokenAmount)
                if feeRequirement.isSufficient {
                    await MainActor.run {
                        let transfer = Web3TransferPreviewViewController(operation: operation, proposer: .dapp(proposer))
                        Web3PopupCoordinator.enqueue(popup: .request(transfer))
                    }
                } else {
                    await MainActor.run {
                        let insufficient = InsufficientBalanceViewController(
                            intent: .externalWeb3Transaction(wallet: wallet, fee: feeRequirement)
                        )
                        Web3PopupCoordinator.enqueue(popup: .request(insufficient))
                    }
                    let error = JSONRPCError(code: 0, message: "Insufficient Fee")
                    try await WalletKit.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
                }
            } catch {
                await MainActor.run {
                    Logger.web3.error(category: "Session", message: "Failed to request tx: \(error)")
                    let title = R.string.localizable.request_rejected()
                    let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
                    Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
                }
                let error = JSONRPCError(code: 0, message: "Local failed")
                try await WalletKit.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        }
    }
    
}

extension WalletConnectSession {
    
    private func requestSolanaSignMessage(with request: Request) {
        assert(Thread.isMainThread)
        requestSigning(with: request) { request in
            try WalletConnectDecodedSigningRequest.solanaSignMessage(request: request)
        }
    }
    
    private func requestSolanaSignTransaction(with request: Request) {
        assert(Thread.isMainThread)
        let proposer = Web3DappProposer(name: name, host: host)
        Task.detached {
            Logger.web3.info(category: "Session", message: "Got tx: \(request.id) \(request.params)")
            do {
                struct RequestParams: Codable {
                    let transaction: String
                }
                let raw = try request.params.get(RequestParams.self).transaction
                guard let transaction = Solana.Transaction(string: raw, encoding: .base64) else {
                    throw Error.invalidParameters
                }
                guard let chain = Web3Chain.chain(caip2: request.chainId) else {
                    throw Error.noChain(request.chainId.absoluteString)
                }
                guard let wallet = Web3WalletDAO.shared.currentSelectedWallet() else {
                    throw Error.noWallet
                }
                guard let address = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: ChainID.solana) else {
                    throw Error.noAddress
                }
                let operation = try await SolanaTransferWithWalletConnectOperation(
                    wallet: wallet,
                    transaction: transaction,
                    fromAddress: address,
                    chain: chain,
                    session: self,
                    request: request
                )
                let fee = try await operation.loadFee()
                let feeRequirement = BalanceRequirement(token: operation.feeToken, amount: fee.tokenAmount)
                if feeRequirement.isSufficient {
                    await MainActor.run {
                        let transfer = Web3TransferPreviewViewController(operation: operation, proposer: .dapp(proposer))
                        Web3PopupCoordinator.enqueue(popup: .request(transfer))
                    }
                } else {
                    await MainActor.run {
                        let insufficient = InsufficientBalanceViewController(
                            intent: .externalWeb3Transaction(wallet: wallet, fee: feeRequirement)
                        )
                        Web3PopupCoordinator.enqueue(popup: .request(insufficient))
                    }
                    let error = JSONRPCError(code: 0, message: "Insufficient Fee")
                    try await WalletKit.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
                }
            } catch {
                Logger.web3.error(category: "Session", message: "Failed to request tx: \(error)")
                await MainActor.run {
                    let title = R.string.localizable.request_rejected()
                    let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
                    Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
                }
                let error = JSONRPCError(code: 0, message: "Local failed")
                try await WalletKit.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        }
    }
    
}

extension WalletConnectSession {
    
    private func requestSigning(
        with request: WalletConnectSign.Request,
        decode: (WalletConnectSign.Request) throws -> (WalletConnectDecodedSigningRequest)
    ) {
        assert(Thread.isMainThread)
        do {
            let decoded = try decode(request)
            guard let wallet = Web3WalletDAO.shared.currentSelectedWallet() else {
                throw Error.noWallet
            }
            guard let chain = Web3Chain.chain(caip2: request.chainId) else {
                throw Error.noChain(request.chainId.absoluteString)
            }
            let address = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chain.chainID)
            guard let address = address?.destination else {
                throw Error.noAddress
            }
            let operation = Web3SignWithWalletConnectOperation(address: address, session: self, request: decoded, chain: chain)
            let signRequest = Web3SignViewController(wallet: wallet, operation: operation, chainName: decoded.chain.name)
            Web3PopupCoordinator.enqueue(popup: .request(signRequest))
        } catch {
            Logger.web3.error(category: "Session", message: "Failed to sign: \(error)")
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
            Web3PopupCoordinator.enqueue(popup: .rejection(title: title, message: message))
            Task {
                let error = JSONRPCError(code: 0, message: error.localizedDescription)
                try await WalletKit.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
            }
        }
    }
    
}
