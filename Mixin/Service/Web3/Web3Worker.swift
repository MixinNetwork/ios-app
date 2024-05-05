import Foundation
import WebKit
import web3
import MixinServices

final class Web3Worker {
    
    private var chain: Web3Chain
    
    private weak var webView: WKWebView?
    
    private var currentProposer: Web3DappProposer {
        Web3DappProposer(name: webView?.title ?? "(no title)",
                         host: webView?.url?.host ?? "(no host)")
    }
    
    init(webView: WKWebView, chain: Web3Chain) {
        self.webView = webView
        self.chain = chain
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
        case .signRawTransaction:
            break
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
            guard let chain = Web3Chain.evmChains.first(where: { $0.id == chainID }) else {
                showAutoHiddenHud(style: .error, text: "Chain not supported")
                send(error: "Unknown Chain", to: request)
                return
            }
            guard let address: String = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress) else {
                showAutoHiddenHud(style: .error, text: "Account Locked")
                send(error: "Account Locked", to: request)
                return
            }
            let setConfig = """
            var config = {
                ethereum: {
                    address: "\(address)",
                    chainId: \(chain.id),
                    rpcUrl: "\(chain.rpcServerURL)"
                }
            };
            mixinwallet.ethereum.setConfig(config);
            """
            webView?.evaluateJavaScript(setConfig)
            
            let emitChange = "mixinwallet.ethereum.emitChainChanged(\"\("0x" + String(chain.id, radix: 16))\");"
            webView?.evaluateJavaScript(emitChange)
            
            sendNull(to: request)
            self.chain = chain
        default:
            send(error: "Unsupported method", to: request)
        }
    }
    
    private func requestAccounts(json: [String: Any], to request: Request) {
        guard let address: String = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress) else {
            send(error: "Account Locked", to: request)
            return
        }
        let script = "mixinwallet.\(request.network.rawValue).setAddress(\"\(address.lowercased())\");"
        webView?.evaluateJavaScript(script)
        send(results: [address], to: request)
    }
    
    private func signMessage(data: Data, to request: Request) {
        guard let address: String = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress) else {
            send(error: "Account Locked", to: request)
            return
        }
        let humanReadable = String(data: data, encoding: .utf8) ?? ""
        let signable: WalletConnectDecodedSigningRequest.Signable = .raw(data)
        let operation = Web3SignWithBrowserWalletOperation(
            address: address,
            proposer: currentProposer,
            humanReadableMessage: humanReadable,
            signable: signable
        ) { signature in
            try await self.send(result: signature, to: request)
        } rejectWith: {
            self.send(error: "User Rejected", to: request)
        }
        let sign = Web3SignViewController(operation: operation, chainName: chain.name)
        Web3PopupCoordinator.enqueue(popup: .request(sign))
    }
    
    private func signTypedData(data: Data, to request: Request) {
        guard let address: String = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress) else {
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
                signable: signable
            ) { signature in
                try await self.send(result: signature, to: request)
            } rejectWith: {
                self.send(error: "User Rejected", to: request)
            }
            let sign = Web3SignViewController(operation: operation, chainName: chain.name)
            Web3PopupCoordinator.enqueue(popup: .request(sign))
        } catch {
            Logger.web3.error(category: "Web3Worker", message: "\(error)")
            send(error: "Invalid Data", to: request)
        }
    }
    
    private func signTransaction(json: [String: Any], to request: Request) {
        guard let address: String = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress) else {
            send(error: "Account Locked", to: request)
            return
        }
        guard let object = json["object"] as? [String: Any] else {
            send(error: "Invalid Data", to: request)
            return
        }
        DispatchQueue.global().async { [chain, proposer=currentProposer] in
            do {
                let preview = try Web3TransactionPreview(json: object)
                let operation = try Web3TransferWithBrowserWalletOperation(
                    fromAddress: address,
                    transaction: preview,
                    chain: chain
                ) { hash in
                    try await self.send(result: hash, to: request)
                } rejectWith: {
                    self.send(error: "User Rejected", to: request)
                }
                DispatchQueue.main.async {
                    let transfer = Web3TransferViewController(operation: operation, proposer: .dapp(proposer))
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
        
        case signRawTransaction
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
        
        init?(value: Any?) {
            guard let rawValue = value as? String else {
                return nil
            }
            self.init(rawValue: rawValue)
        }
        
    }
    
    private enum ProviderNetwork: String, Decodable {
        
        case ethereum
        
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
