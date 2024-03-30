import Foundation

public struct Web3Chain {
    
    public let chainID: String
    public let rpc: URL
    public let dapps: [Web3Dapp]
    
}

extension Web3Chain: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case rpc
        case dapps
    }
    
}

extension Web3Chain {
    
    public static let globalChainsDidUpdateNotification = Notification.Name("one.mixin.service.Web3Chain.Update")
    
    // Key is `chainID`
    public private(set) static var global: [String: Web3Chain]?
    
    public static func synchronize() {
        ExternalAPI.chains { result in
            switch result {
            case .success(let chains):
                let idMappedChains = chains.reduce(into: [:]) { result, chain in
                    result[chain.chainID] = chain
                }
                Logger.web3.debug(category: "Web3Chain", message: "Loaded \(idMappedChains.count) chains")
                Self.global = idMappedChains
                AppGroupUserDefaults.Wallet.web3RPCURL = idMappedChains.mapValues(\.rpc.absoluteString)
                NotificationCenter.default.post(name: Self.globalChainsDidUpdateNotification, object: nil)
            case .failure(let error):
                Logger.web3.debug(category: "Web3Chain", message: "Failed to load: \(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: synchronize)
            }
        }
    }
    
}
