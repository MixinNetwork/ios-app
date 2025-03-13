import Foundation
import OrderedCollections
import web3
import Web3Wallet
import MixinServices

final class Web3Chain {
    
    enum Kind: CaseIterable {
        
        case evm
        case solana
        
        var chains: [Web3Chain] {
            switch self {
            case .evm:
                [.ethereum, .polygon, .bnbSmartChain, .arbitrum, .base, .optimism]
            case .solana:
                [.solana]
            }
        }
        
    }
    
    enum KindSpecification {
        case evm(chainID: Int)
        case solana
    }
    
    let kind: Kind
    let specification: KindSpecification
    let web3ChainID: String
    let mixinChainID: String
    let feeTokenAssetID: String
    let name: String
    let failsafeRPCServerURL: URL
    let caip2: Blockchain
    
    private(set) var dapps: [Web3Dapp] = []
    
    var rpcServerURL: URL {
        if let string = AppGroupUserDefaults.web3RPCURL[mixinChainID],
           let url = URL(string: string)
        {
            url
        } else {
            failsafeRPCServerURL
        }
    }
    
    private init(
        specification: KindSpecification, web3ChainID: String,
        mixinChainID: String, feeTokenAssetID: String, name: String,
        failsafeRPCServerURL: URL, caip2: Blockchain
    ) {
        let kind: Kind = switch specification {
        case .evm:
                .evm
        case .solana:
                .solana
        }
        
        self.kind = kind
        self.specification = specification
        self.web3ChainID = web3ChainID
        self.mixinChainID = mixinChainID
        self.feeTokenAssetID = feeTokenAssetID
        self.name = name
        self.failsafeRPCServerURL = failsafeRPCServerURL
        self.caip2 = caip2
    }
    
    static func evm(
        chainID: Int, web3ChainID: String, mixinChainID: String,
        feeTokenAssetID: String, name: String, failsafeRPCServerURL: URL
    ) -> Web3Chain {
        Web3Chain(
            specification: .evm(chainID: chainID),
            web3ChainID: web3ChainID,
            mixinChainID: mixinChainID,
            feeTokenAssetID: feeTokenAssetID,
            name: name,
            failsafeRPCServerURL: failsafeRPCServerURL,
            caip2: Blockchain("eip155:\(chainID)")!
        )
    }
    
    static func solana(
        reference: String, web3ChainID: String, mixinChainID: String,
        feeTokenAssetID: String, name: String, failsafeRPCServerURL: URL
    ) -> Web3Chain {
        Web3Chain(
            specification: .solana,
            web3ChainID: web3ChainID,
            mixinChainID: mixinChainID,
            feeTokenAssetID: feeTokenAssetID,
            name: name,
            failsafeRPCServerURL: failsafeRPCServerURL,
            caip2: Blockchain("solana:\(reference)")!
        )
    }
    
}

// MARK: - Equatable
extension Web3Chain: Equatable {
    
    static func == (lhs: Web3Chain, rhs: Web3Chain) -> Bool {
        lhs.caip2 == rhs.caip2
    }
    
}

// MARK: - Hashable
extension Web3Chain: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(caip2)
    }
    
}

// MARK: - Search
extension Web3Chain {
    
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
    
    private static let mixinChainIDMap: OrderedDictionary<String, Web3Chain> = {
        all.reduce(into: [:]) { result, chain in
            result[chain.mixinChainID] = chain
        }
    }()
    
    static func chain(caip2: Blockchain) -> Web3Chain? {
        caip2Map[caip2]
    }
    
    static func chain(web3ChainID id: String) -> Web3Chain? {
        web3ChainIDMap[id]
    }
    
    static func chain(mixinChainID id: String) -> Web3Chain? {
        mixinChainIDMap[id]
    }
    
    static func evmChain(chainID: Int) -> Web3Chain? {
        guard let caip2 = Blockchain("eip155:\(chainID)") else {
            return nil
        }
        return chain(caip2: caip2)
    }
    
}

extension Web3Chain {
    
    func feeToken() throws -> MixinTokenItem? {
        if let token = TokenDAO.shared.tokenItem(assetID: feeTokenAssetID) {
           return token
        } else {
            let token = try SafeAPI.assets(id: feeTokenAssetID).get()
            return TokenDAO.shared.saveAndFetch(token: token)
        }
    }
    
}

// MARK: - Chains
extension Web3Chain {
    
    static let all = Kind.allCases.reduce(into: []) { results, kind in
        results.append(contentsOf: kind.chains)
    }
    
    static let ethereum = Web3Chain.evm(
        chainID: 1,
        web3ChainID: "ethereum",
        mixinChainID: ChainID.ethereum,
        feeTokenAssetID: AssetID.eth,
        name: "Ethereum",
        failsafeRPCServerURL: URL(string: "https://cloudflare-eth.com")!
    )
    
    static let polygon = Web3Chain.evm(
        chainID: 137,
        web3ChainID: "polygon",
        mixinChainID: ChainID.polygon,
        feeTokenAssetID: AssetID.matic,
        name: "Polygon",
        failsafeRPCServerURL: URL(string: "https://polygon-rpc.com")!
    )
    
    static let bnbSmartChain = Web3Chain.evm(
        chainID: 56,
        web3ChainID: "binance-smart-chain",
        mixinChainID: ChainID.bnbSmartChain,
        feeTokenAssetID: AssetID.bnb,
        name: "BSC",
        failsafeRPCServerURL: URL(string: "https://endpoints.omniatech.io/v1/bsc/mainnet/public")!
    )
    
    static let arbitrum = Web3Chain.evm(
        chainID: 42161,
        web3ChainID: "arbitrum",
        mixinChainID: ChainID.arbitrum,
        feeTokenAssetID: AssetID.eth,
        name: "Arbitrum",
        failsafeRPCServerURL: URL(string: "https://arbitrum.llamarpc.com")!
    )
    
    static let base = Web3Chain.evm(
        chainID: 8453,
        web3ChainID: "base",
        mixinChainID: ChainID.base,
        feeTokenAssetID: AssetID.eth,
        name: "Base",
        failsafeRPCServerURL: URL(string: "https://base.llamarpc.com")!
    )
    
    static let optimism = Web3Chain.evm(
        chainID: 10,
        web3ChainID: "optimism",
        mixinChainID: ChainID.optimism,
        feeTokenAssetID: AssetID.eth,
        name: "Optimism",
        failsafeRPCServerURL: URL(string: "https://optimism.llamarpc.com")!
    )
    
    static let solana = Web3Chain.solana(
        reference: "4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ",
        web3ChainID: "solana",
        mixinChainID: ChainID.solana,
        feeTokenAssetID: AssetID.sol,
        name: "Solana",
        failsafeRPCServerURL: URL(string: "https://api.mainnet-beta.solana.com")!
    )
    
#if DEBUG
    static let solanaDevnet = Web3Chain.solana(
        reference: "EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
        web3ChainID: "solana",
        mixinChainID: ChainID.solana,
        feeTokenAssetID: AssetID.sol,
        name: "Solana",
        failsafeRPCServerURL: URL(string: "https://api.devnet.solana.com")!
    )
#endif
    
}

// MARK: - Dapp Sync
extension Web3Chain {
    
    static func synchronize() {
        Web3API.dapps(queue: .global()) { result in
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
                        guard let dapps = dapps[chain.mixinChainID] else {
                            continue
                        }
                        chain.dapps = dapps
                    }
                }
            case .failure(.httpTransport(.requestAdaptationFailed)):
                // Logout
                break
            case .failure(let error):
                Logger.web3.info(category: "Web3Chain", message: "Failed to load: \(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: synchronize)
            }
        }
    }
    
}
