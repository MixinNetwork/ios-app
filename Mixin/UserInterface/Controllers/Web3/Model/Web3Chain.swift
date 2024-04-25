import Foundation
import OrderedCollections
import web3
import Web3Wallet
import MixinServices

final class Web3Chain {
    
    static let `default`: Web3Chain = .ethereum
    static let all: [Web3Chain] = Array(evmChains)
    static let evmChains: OrderedSet<Web3Chain> = [.ethereum, .polygon, .bnbSmartChain]
    
    static let ethereum = Web3Chain(
        id: 1,
        internalID: ChainID.ethereum,
        name: "Ethereum",
        failsafeRPCServerURL: URL(string: "https://cloudflare-eth.com")!,
        feeSymbol: "ETH",
        caip2: Blockchain("eip155:1")!
    )
    
    static let polygon = Web3Chain(
        id: 137,
        internalID: ChainID.polygon,
        name: "Polygon",
        failsafeRPCServerURL: URL(string: "https://polygon-rpc.com")!,
        feeSymbol: "MATIC",
        caip2: Blockchain("eip155:137")!
    )
    
    static let bnbSmartChain = Web3Chain(
        id: 56,
        internalID: ChainID.bnbSmartChain,
        name: "BSC",
        failsafeRPCServerURL: URL(string: "https://endpoints.omniatech.io/v1/bsc/mainnet/public")!,
        feeSymbol: "BNB",
        caip2: Blockchain("eip155:56")!
    )
    
    private static let caip2Map: OrderedDictionary<Blockchain, Web3Chain> = [
        Web3Chain.ethereum.caip2:      .ethereum,
        Web3Chain.polygon.caip2:       .polygon,
        Web3Chain.bnbSmartChain.caip2: .bnbSmartChain,
    ]
    
    private static let mixinChainIDMap: OrderedDictionary<String, Web3Chain> = [
        Web3Chain.ethereum.mixinChainID:      .ethereum,
        Web3Chain.polygon.mixinChainID:       .polygon,
        Web3Chain.bnbSmartChain.mixinChainID: .bnbSmartChain,
    ]
    
    let id: Int
    let mixinChainID: String
    let name: String
    let failsafeRPCServerURL: URL
    let feeSymbol: String
    let caip2: Blockchain
    
    private(set) var dapps: [Web3Dapp] = []
    
    var rpcServerURL: URL {
        if let string = AppGroupUserDefaults.web3RPCURL[mixinChainID], let url = URL(string: string) {
            url
        } else {
            failsafeRPCServerURL
        }
    }
    
    private init(
        id: Int, internalID: String, name: String,
        failsafeRPCServerURL: URL, feeSymbol: String,
        caip2: Blockchain
    ) {
        self.id = id
        self.mixinChainID = internalID
        self.name = name
        self.failsafeRPCServerURL = failsafeRPCServerURL
        self.feeSymbol = feeSymbol
        self.caip2 = caip2
    }
    
    static func chain(caip2: Blockchain) -> Web3Chain? {
        caip2Map[caip2]
    }
    
    static func chain(mixinChainID id: String) -> Web3Chain? {
        mixinChainIDMap[id]
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
        ExternalAPI.dapps { result in
            switch result {
            case .success(let updates):
                Logger.web3.info(category: "Web3Chain", message: "Loaded \(updates.count) updates")
                var rpcURLs: [String: String] = [:]
                for update in updates {
                    rpcURLs[update.chainID] = update.rpc.absoluteString
                    chain(mixinChainID: update.chainID)?.dapps = update.dapps
                }
                AppGroupUserDefaults.web3RPCURL = rpcURLs
            case .failure(let error):
                Logger.web3.info(category: "Web3Chain", message: "Failed to load: \(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: synchronize)
            }
        }
    }
    
}
