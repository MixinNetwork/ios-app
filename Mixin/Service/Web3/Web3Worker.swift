import Foundation
import WebKit
import web3
import MixinServices

final class Web3Worker {
    
    private let siwsIssuedAtThreshold: TimeInterval = 10 * .minute
    
    private var evmChain: Web3Chain
    private var solanaChain: Web3Chain
    
    private weak var webView: WKWebView?
    
    private var currentProposer: Web3DappProposer {
        Web3DappProposer(name: webView?.title ?? "(no title)",
                         host: webView?.url?.host ?? "(no host)")
    }
    
    init(webView: WKWebView, evmChain: Web3Chain, solanaChain: Web3Chain) {
        self.webView = webView
        self.evmChain = evmChain
        self.solanaChain = solanaChain
    }
    
    func handleRequest(json: [String: Any]) {
        guard let request = Request(json: json) else {
            return
        }
        guard let method = DAppMethod(value: json["name"]) else {
            send(error: "Unsupported method", to: request)
            return
        }
        switch method {
        case .requestAccounts:
            requestAccounts(json: json, to: request)
        case .signTransaction:
            signTransaction(json: json, to: request)
        case .signMessage:
            if let data = messageData(json: json) {
                signMessage(data: data, to: request)
            } else {
                send(error: "Invalid Data", to: request)
            }
        case .signPersonalMessage:
            if let data = messageData(json: json) {
                signMessage(data: data, to: request)
            } else {
                send(error: "Invalid Data", to: request)
            }
        case .signTypedMessage:
            guard
                let object = json["object"] as? [String: Any],
                let string = object["raw"] as? String,
                let data = string.data(using: .utf8)
            else {
                send(error: "Invalid Data", to: request)
                return
            }
            signTypedData(data: data, to: request)
        case .sendTransaction:
            break
        case .ecRecover:
            send(error: "Unsupported method", to: request)
        case .addEthereumChain:
            send(error: "Unsupported method", to: request)
        case .switchChain, .switchEthereumChain:
            guard let chainID = ethereumChainID(json: json) else {
                send(error: "Unsupported Chain", to: request)
                return
            }
            guard let chain = Web3Chain.chain(evmChainID: chainID) else {
                showAutoHiddenHud(style: .error, text: "Chain not supported")
                send(error: "Unknown Chain", to: request)
                return
            }
            guard let address = Web3AddressDAO.shared.classicWalletAddress(chainID: ChainID.ethereum)?.destination else {
                showAutoHiddenHud(style: .error, text: "Account Locked")
                send(error: "Account Locked", to: request)
                return
            }
            let setConfig = """
            var config = {
                ethereum: {
                    address: "\(address)",
                    chainId: \(chainID),
                    rpcUrl: "\(chain.rpcServerURL)"
                }
            };
            mixinwallet.ethereum.setConfig(config);
            """
            webView?.evaluateJavaScript(setConfig)
            
            let hexChainID = "0x" + String(chainID, radix: 16)
            let emitChange = "mixinwallet.ethereum.emitChainChanged(\"\(hexChainID)\");"
            webView?.evaluateJavaScript(emitChange)
            
            sendNull(to: request)
            self.evmChain = chain
        case .signRawTransaction:
            signRawTransaction(json: json, to: request)
        case .signIn:
            signIn(json: json, to: request)
        default:
            send(error: "Unsupported method", to: request)
        }
    }
    
    private func requestAccounts(json: [String: Any], to request: Request) {
        let address = switch request.network {
        case .ethereum:
            Web3AddressDAO.shared.classicWalletAddress(chainID: ChainID.ethereum)
        case .solana:
            Web3AddressDAO.shared.classicWalletAddress(chainID: ChainID.solana)
        }
        guard let address = address?.destination else {
            send(error: "Account Locked", to: request)
            return
        }
        let script = "mixinwallet.\(request.network.rawValue).setAddress(\"\(address.lowercased())\");"
        webView?.evaluateJavaScript(script)
        send(results: [address], to: request)
    }
    
    private func signMessage(data: Data, to request: Request) {
        guard let address = Web3AddressDAO.shared.classicWalletAddress(chainID: ChainID.ethereum)?.destination else {
            send(error: "Account Locked", to: request)
            return
        }
        let humanReadable = String(data: data, encoding: .utf8) ?? ""
        let signable: WalletConnectDecodedSigningRequest.Signable = .raw(data)
        let operation = Web3SignWithBrowserWalletOperation(
            address: address,
            proposer: currentProposer,
            humanReadableMessage: humanReadable,
            signable: signable,
            chain: evmChain
        ) { signature in
            try await self.send(result: signature, to: request)
        } rejectWith: {
            self.send(error: "User Rejected", to: request)
        }
        let sign = Web3SignViewController(operation: operation, chainName: evmChain.name)
        Web3PopupCoordinator.enqueue(popup: .request(sign))
    }
    
    private func signTypedData(data: Data, to request: Request) {
        guard let address: String = Web3AddressDAO.shared.classicWalletAddress(chainID: ChainID.ethereum)?.destination else {
            send(error: "Account Locked", to: request)
            return
        }
        let humanReadable = String(data: data, encoding: .utf8) ?? ""
        do {
            let typedData = try JSONDecoder.default.decode(TypedData.self, from: data)
            let signable: WalletConnectDecodedSigningRequest.Signable = .typed(typedData)
            let operation = Web3SignWithBrowserWalletOperation(
                address: address,
                proposer: currentProposer,
                humanReadableMessage: humanReadable,
                signable: signable,
                chain: evmChain
            ) { signature in
                try await self.send(result: signature, to: request)
            } rejectWith: {
                self.send(error: "User Rejected", to: request)
            }
            let sign = Web3SignViewController(operation: operation, chainName: evmChain.name)
            Web3PopupCoordinator.enqueue(popup: .request(sign))
        } catch {
            Logger.web3.error(category: "Web3Worker", message: "\(error)")
            send(error: "Invalid Data", to: request)
        }
    }
    
    private func signTransaction(json: [String: Any], to request: Request) {
        guard let object = json["object"] as? [String: Any] else {
            send(error: "Invalid Data", to: request)
            return
        }
        guard let address = Web3AddressDAO.shared.classicWalletAddress(chainID: ChainID.ethereum) else {
            send(error: "Account Locked", to: request)
            return
        }
        DispatchQueue.global().async { [evmChain, proposer=currentProposer] in
            do {
                let preview = try EVMTransactionPreview(json: object)
                let operation = try EVMTransferWithBrowserWalletOperation(
                    walletID: address.walletID,
                    fromAddress: address.destination,
                    transaction: preview,
                    chain: evmChain
                ) { hash in
                    try await self.send(result: hash, to: request)
                } rejectWith: {
                    self.send(error: "User Rejected", to: request)
                }
                DispatchQueue.main.async {
                    let transfer = Web3TransferPreviewViewController(operation: operation, proposer: .dapp(proposer))
                    Web3PopupCoordinator.enqueue(popup: .request(transfer))
                }
            } catch {
                DispatchQueue.main.async {
                    self.send(error: "\(error)", to: request)
                }
            }
        }
    }
    
    private func signIn(json: [String: Any], to request: Request) {
        guard
            let object = json["object"] as? [String: Any],
            let input = object["data"] as? [String: Any]
        else {
            send(error: "Invalid Data", to: request)
            return
        }
        guard let myAddress = Web3AddressDAO.shared.classicWalletAddress(chainID: ChainID.solana)?.destination else {
            send(error: "Account Locked", to: request)
            return
        }
        guard let webViewURL = webView?.url, let webViewHost = webViewURL.host else {
            send(error: "Empty WebView", to: request)
            return
        }
        if let address = input["address"] as? String, address != myAddress {
            send(error: "Mismatched address", to: request)
            return
        }
        if let domain = input["domain"] as? String, domain != webViewHost {
            send(error: "Mismatched domain", to: request)
            return
        }
        
        var message = "\(webViewHost) wants you to sign in with your Solana account:\n"
        message += "\(myAddress)"
        if let statement = input["statement"] as? String {
            message += "\n\n\(statement)"
        }
        var fields: [String] = []
        if let uri = input["uri"] as? String {
            let origin: String? = {
                guard webViewURL.scheme == "https", let host = webViewURL.host else {
                    return nil
                }
                var origin = "https://" + host
                if let port = webViewURL.port, ![80, 443].contains(port) {
                    origin.append(":\(port)")
                }
                origin += "/"
                return origin
            }()
            guard uri == origin else {
                send(error: "Mismatched URI", to: request)
                return
            }
            fields.append("URI: \(uri)")
        }
        if let version = input["version"] as? String {
            fields.append("Version: \(version)")
        }
        if let id = input["chainId"] as? String {
            // TODO: Compare `chainId` with actual value
            guard ["solana:mainnet", "mainnet"].contains(id) && solanaChain == .solana else {
                send(error: "Mismatched Chain ID", to: request)
                return
            }
            fields.append("Chain ID: \(id)")
        }
        if let nonce = input["nonce"] as? String {
            fields.append("Nonce: \(nonce)")
        }
        let issuedAt: Date?
        if let iat = input["issuedAt"] as? String {
            guard 
                let iatDate = DateFormatter.iso8601Full.date(from: iat),
                abs(iatDate.timeIntervalSinceNow) < siwsIssuedAtThreshold
            else {
                send(error: "Invalid issuedAt", to: request)
                return
            }
            issuedAt = iatDate
            fields.append("Issued At: \(iat)")
        } else {
            issuedAt = nil
        }
        let expirationTime: Date?
        if let exp = input["expirationTime"] as? String {
            guard
                let expDate = DateFormatter.iso8601Full.date(from: exp),
                expDate.timeIntervalSinceNow <= 0
            else {
                send(error: "Invalid expirationTime", to: request)
                return
            }
            if let issuedAt, issuedAt >= expDate {
                send(error: "issuedAt expired", to: request)
                return
            }
            expirationTime = expDate
            fields.append("Expiration Time: \(exp)")
        } else {
            expirationTime = nil
        }
        if let notBefore = input["notBefore"] as? String {
            guard let nbf = DateFormatter.iso8601Full.date(from: notBefore) else {
                send(error: "Invalid notBefore", to: request)
                return
            }
            if let expirationTime, nbf > expirationTime {
                send(error: "Invalid notBefore", to: request)
                return
            }
            fields.append("Not Before: \(notBefore)")
        }
        if let id = input["requestId"] as? String {
            fields.append("Request ID: \(id)")
        }
        if let resources = input["resources"] as? [String] {
            fields.append("Resources:")
            for resource in resources {
                fields.append("- \(resource)")
            }
        }
        if !fields.isEmpty {
            message += "\n\n\(fields.joined(separator: "\n"))"
        }
        
        guard let messageData = message.data(using: .utf8) else {
            send(error: "Invalid Data", to: request)
            return
        }
        let signable: WalletConnectDecodedSigningRequest.Signable = .raw(messageData)
        let operation = Web3SignWithBrowserWalletOperation(
            address: myAddress,
            proposer: currentProposer,
            humanReadableMessage: message,
            signable: signable,
            chain: solanaChain
        ) { signature in
            try await self.send(result: signature, to: request)
        } rejectWith: {
            self.send(error: "User Rejected", to: request)
        }
        let sign = Web3SignViewController(operation: operation, chainName: solanaChain.name)
        Web3PopupCoordinator.enqueue(popup: .request(sign))
    }
    
    private func signRawTransaction(json: [String: Any], to request: Request) {
        guard
            let object = json["object"] as? [String: Any],
            let raw = object["raw"] as? String,
            let transaction = Solana.Transaction(string: raw, encoding: .base64)
        else {
            send(error: "Invalid Data", to: request)
            return
        }
        guard let walletID = Web3WalletDAO.shared.classicWallet()?.walletID else {
            send(error: "Account Locked", to: request)
            return
        }
        guard let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: ChainID.solana) else {
            send(error: "No Address", to: request)
            return
        }
        DispatchQueue.global().async { [solanaChain, proposer=currentProposer] in
            do {
                let operation = try SolanaTransferWithCustomRespondingOperation(
                    walletID: walletID,
                    transaction: transaction,
                    fromAddress: address.destination,
                    chain: solanaChain
                ) { signature in
                    try await self.send(result: signature, to: request)
                } rejectWith: {
                    self.send(error: "User Rejected", to: request)
                }
                DispatchQueue.main.async {
                    let transfer = Web3TransferPreviewViewController(operation: operation, proposer: .dapp(proposer))
                    Web3PopupCoordinator.enqueue(popup: .request(transfer))
                }
            } catch {
                DispatchQueue.main.async {
                    self.send(error: "\(error)", to: request)
                }
            }
        }
    }
    
    @MainActor @discardableResult
    private func send(result: String, to request: Request) async throws -> Any? {
        let script = String(format: "mixinwallet.\(request.network.rawValue).sendResponse(%ld, \'%@\')", request.id, result)
        return try await withCheckedThrowingContinuation { continuation in
            // Don't use async version of `evaluateJavaScript`, it crashes on iOS 14
            if let webView {
                webView.evaluateJavaScript(script) { (result, error) in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func send(results: [String], to request: Request) {
        let response = results.map { result in
            "\"\(result)\""
        }
        let script = String(format: "mixinwallet.\(request.network.rawValue).sendResponse(%ld, [%@])", request.id, response.joined(separator: ","))
        webView?.evaluateJavaScript(script)
    }
    
    private func send(error: String, to request: Request) {
        let script = String(format: "mixinwallet.\(request.network.rawValue).sendError(%ld, \"%@\")", request.id, error)
        webView?.evaluateJavaScript(script)
    }
    
    private func sendNull(to request: Request) {
        let script = String(format: "mixinwallet.\(request.network.rawValue).sendResponse(%ld, null)", request.id)
        webView?.evaluateJavaScript(script)
    }
    
}

extension Web3Worker {
    
    private enum DAppMethod: String, Decodable, CaseIterable {
        
        // EVM
        case signTransaction
        case signMessage
        case signTypedMessage
        case signPersonalMessage
        case sendTransaction
        case ecRecover
        case requestAccounts
        case watchAsset
        case addEthereumChain
        case switchEthereumChain // legacy compatible
        case switchChain
        
        // Solana
        case signIn
        case signRawTransaction
        
        init?(value: Any?) {
            guard let rawValue = value as? String else {
                return nil
            }
            self.init(rawValue: rawValue)
        }
        
    }
    
    private enum ProviderNetwork: String, Decodable {
        
        case ethereum
        case solana
        
        init?(value: Any?) {
            guard let rawValue = value as? String else {
                return nil
            }
            self.init(rawValue: rawValue)
        }
        
    }
    
    private struct Request {
        
        let network: ProviderNetwork
        let id: Int64
        
        init?(json: [String: Any]) {
            guard
                let network = Web3Worker.ProviderNetwork(value: json["network"]),
                let id = json["id"] as? Int64
            else {
                return nil
            }
            self.network = network
            self.id = id
        }
        
    }
    
    private func messageData(json: [String: Any]) -> Data? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["data"] as? String,
            let data = Data(hexEncodedString: string.dropFirst(2))
        else {
            return nil
        }
        return data
    }
    
    private func ethereumChainID(json: [String: Any]) -> Int? {
        guard
            let params = json["object"] as? [String: Any],
            let string = params["chainId"] as? String,
            let chainID = Int(String(string.dropFirst(2)), radix: 16),
            chainID > 0
        else {
            return nil
        }
        return chainID
    }
    
}
