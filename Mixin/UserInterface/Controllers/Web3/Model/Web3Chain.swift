import Foundation
import OrderedCollections
import web3
import Web3Wallet
import MixinServices

final class Web3Chain {
    
    static let `default`: Web3Chain = .ethereum
    static let all: [Web3Chain] = Array(evmChains)
    static let evmChains: OrderedSet<Web3Chain> = [
        .ethereum, .polygon, .bnbSmartChain, arbitrum, .base, .optimism,
    ]
    
    static let ethereum = Web3Chain(
        id: 1,
        web3ChainID: "ethereum",
        mixinChainID: ChainID.ethereum,
        feeTokenAssetID: AssetID.eth,
        name: "Ethereum",
        failsafeRPCServerURL: URL(string: "https://cloudflare-eth.com")!,
        caip2: Blockchain("eip155:1")!
    )
    
    static let polygon = Web3Chain(
        id: 137,
        web3ChainID: "polygon",
        mixinChainID: ChainID.polygon,
        feeTokenAssetID: AssetID.matic,
        name: "Polygon",
        failsafeRPCServerURL: URL(string: "https://polygon-rpc.com")!,
        caip2: Blockchain("eip155:137")!
    )
    
    static let bnbSmartChain = Web3Chain(
        id: 56,
        web3ChainID: "binance-smart-chain",
        mixinChainID: ChainID.bnbSmartChain,
        feeTokenAssetID: AssetID.bnb,
        name: "BSC",
        failsafeRPCServerURL: URL(string: "https://endpoints.omniatech.io/v1/bsc/mainnet/public")!,
        caip2: Blockchain("eip155:56")!
    )
    
    static let arbitrum = Web3Chain(
        id: 42161,
        web3ChainID: "arbitrum",
        mixinChainID: nil,
        feeTokenAssetID: AssetID.eth,
        name: "Arbitrum",
        failsafeRPCServerURL: URL(string: "https://arbitrum.llamarpc.com")!,
        caip2: Blockchain("eip155:42161")!
    )
    
    static let base = Web3Chain(
        id: 8453,
        web3ChainID: "base",
        mixinChainID: nil,
        feeTokenAssetID: AssetID.eth,
        name: "Base",
        failsafeRPCServerURL: URL(string: "https://base.llamarpc.com")!,
        caip2: Blockchain("eip155:8453")!
    )
    
    static let optimism = Web3Chain(
        id: 10,
        web3ChainID: "optimism",
        mixinChainID: nil,
        feeTokenAssetID: AssetID.eth,
        name: "Optimism",
        failsafeRPCServerURL: URL(string: "https://optimism.llamarpc.com")!,
        caip2: Blockchain("eip155:10")!
    )
    
    private static let caip2Map: OrderedDictionary<Blockchain, Web3Chain> = {
        all.reduce(into: [:]) { result, chain in
            result[chain.caip2] = chain
        }
    }()
    
    private static let web3ChainIDMap: OrderedDictionary<String, Web3Chain> = {
        all.reduce(into: [:]) { result, chain in
            result[chain.web3ChainID] = chain
        }
    }()
    
    let id: Int
    let web3ChainID: String
    let mixinChainID: String?
    let feeTokenAssetID: String
    let name: String
    let failsafeRPCServerURL: URL
    let caip2: Blockchain
    
    private(set) var dapps: [Web3Dapp] = []
    
    var rpcServerURL: URL {
        if let mixinChainID,
           let string = AppGroupUserDefaults.web3RPCURL[mixinChainID],
           let url = URL(string: string)
        {
            url
        } else {
            failsafeRPCServerURL
        }
    }
    
    private init(
        id: Int, web3ChainID: String, mixinChainID: String?,
        feeTokenAssetID: String, name: String, failsafeRPCServerURL: URL,
        caip2: Blockchain
    ) {
        self.id = id
        self.web3ChainID = web3ChainID
        self.mixinChainID = mixinChainID
        self.feeTokenAssetID = feeTokenAssetID
        self.name = name
        self.failsafeRPCServerURL = failsafeRPCServerURL
        self.caip2 = caip2
    }
    
    static func chain(caip2: Blockchain) -> Web3Chain? {
        caip2Map[caip2]
    }
    
    static func chain(web3ChainID id: String) -> Web3Chain? {
        web3ChainIDMap[id]
    }
    
    func makeEthereumClient() -> EthereumHttpClient {
        let network: EthereumNetwork = switch self {
        case .ethereum:
                .mainnet
        default:
                .custom("\(id)")
        }
        return EthereumHttpClient(url: rpcServerURL, network: network)
    }
    
}

extension Web3Chain: Equatable {
    
    static func == (lhs: Web3Chain, rhs: Web3Chain) -> Bool {
        lhs.id == rhs.id
    }
    
}

extension Web3Chain: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

extension Web3Chain {
    
    static func synchronize() {
        ExternalAPI.dapps(queue: .global()) { result in
            switch result {
            case .success(let updates):
                Logger.web3.info(category: "Web3Chain", message: "Loaded \(updates.count) updates")
                var rpcURLs: [String: String] = [:]
                var dapps: [String: [Web3Dapp]] = [:]
                for update in updates {
                    rpcURLs[update.chainID] = update.rpc.absoluteString
                    dapps[update.chainID] = update.dapps
                }
                DispatchQueue.main.async {
                    AppGroupUserDefaults.web3RPCURL = rpcURLs
                    for chain in Web3Chain.all {
                        guard 
                            let mixinChainID = chain.mixinChainID,
                            let dapps = dapps[mixinChainID]
                        else {
                            continue
                        }
                        chain.dapps = dapps
                    }
                }
            case .failure(let error):
                Logger.web3.info(category: "Web3Chain", message: "Failed to load: \(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: synchronize)
            }
        }
    }
    
}
