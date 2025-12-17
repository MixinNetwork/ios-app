import Foundation
import OrderedCollections
import web3
import ReownWalletKit
import MixinServices

final class Web3Chain {
    
    enum Kind: CaseIterable {
        
        case evm
        case solana
        
        var chains: [Web3Chain] {
            switch self {
            case .evm:
                [.ethereum, .polygon, .bnbSmartChain, .base, .arbitrumOne, .opMainnet, .avalancheCChain]
            case .solana:
                [.solana]
            }
        }
        
        static func singleKindWallet(chainIDs: Set<String>) -> Kind? {
            if chainIDs.contains(ChainID.ethereum) {
                .evm
            } else if chainIDs.contains(ChainID.solana) {
                .solana
            } else {
                nil
            }
        }
        
    }
    
    enum KindSpecification {
        case evm(chainID: Int)
        case solana
    }
    
    let kind: Kind
    let specification: KindSpecification
    let chainID: String
    let feeTokenAssetID: String
    let name: String
    let failsafeRPCServerURL: URL
    let caip2: Blockchain
    
    private(set) var dapps: [Web3Dapp] = []
    
    var rpcServerURL: URL {
        if let string = AppGroupUserDefaults.web3RPCURL[chainID],
           let url = URL(string: string)
        {
            url
        } else {
            failsafeRPCServerURL
        }
    }
    
    private init(
        specification: KindSpecification, mixinChainID: String,
        feeTokenAssetID: String, name: String,
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
        self.chainID = mixinChainID
        self.feeTokenAssetID = feeTokenAssetID
        self.name = name
        self.failsafeRPCServerURL = failsafeRPCServerURL
        self.caip2 = caip2
    }
    
    static func evm(
        chainID: Int, mixinChainID: String, feeTokenAssetID: String,
        name: String, failsafeRPCServerURL: URL
    ) -> Web3Chain {
        Web3Chain(
            specification: .evm(chainID: chainID),
            mixinChainID: mixinChainID,
            feeTokenAssetID: feeTokenAssetID,
            name: name,
            failsafeRPCServerURL: failsafeRPCServerURL,
            caip2: Blockchain("eip155:\(chainID)")!
        )
    }
    
    static func solana(
        reference: String, mixinChainID: String, feeTokenAssetID: String,
        name: String, failsafeRPCServerURL: URL
    ) -> Web3Chain {
        Web3Chain(
            specification: .solana,
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
    
    private static let chainIDMap: OrderedDictionary<String, Web3Chain> = {
        all.reduce(into: [:]) { result, chain in
            result[chain.chainID] = chain
        }
    }()
    
    static func chain(caip2: Blockchain) -> Web3Chain? {
        caip2Map[caip2]
    }
    
    static func chain(chainID id: String) -> Web3Chain? {
        chainIDMap[id]
    }
    
    static func chain(evmChainID: Int) -> Web3Chain? {
        guard let caip2 = Blockchain("eip155:\(evmChainID)") else {
            return nil
        }
        return chain(caip2: caip2)
    }
    
}

extension Web3Chain {
    
    func feeToken(walletID: String) throws -> Web3TokenItem? {
        Web3TokenDAO.shared.token(walletID: walletID, assetID: feeTokenAssetID)
    }
    
}

// MARK: - Chains
extension Web3Chain {
    
    static let all: [Web3Chain] = {
        let chains: [Web3Chain] = [
            .ethereum, .solana, .bnbSmartChain, .base, .polygon, .arbitrumOne, .opMainnet, .avalancheCChain,
        ]
        // Make sure all chains are included
        let allChains = Kind.allCases.reduce(into: []) { results, kind in
            results.append(contentsOf: kind.chains)
        }
        assert(chains.count == allChains.count, "New chains added? Put it into `chains` with ordering.")
        return chains
    }()
    
    static let ethereum = Web3Chain.evm(
        chainID: 1,
        mixinChainID: ChainID.ethereum,
        feeTokenAssetID: AssetID.eth,
        name: "Ethereum",
        failsafeRPCServerURL: URL(string: "https://cloudflare-eth.com")!
    )
    
    static let polygon = Web3Chain.evm(
        chainID: 137,
        mixinChainID: ChainID.polygon,
        feeTokenAssetID: AssetID.matic,
        name: "Polygon",
        failsafeRPCServerURL: URL(string: "https://polygon-rpc.com")!
    )
    
    static let bnbSmartChain = Web3Chain.evm(
        chainID: 56,
        mixinChainID: ChainID.bnbSmartChain,
        feeTokenAssetID: AssetID.bnb,
        name: "BSC",
        failsafeRPCServerURL: URL(string: "https://endpoints.omniatech.io/v1/bsc/mainnet/public")!
    )
    
    static let base = Web3Chain.evm(
        chainID: 8453,
        mixinChainID: ChainID.base,
        feeTokenAssetID: AssetID.baseETH,
        name: "Base",
        failsafeRPCServerURL: URL(string: "https://base.llamarpc.com")!
    )
    
    static let arbitrumOne = Web3Chain.evm(
        chainID: 42161,
        mixinChainID: ChainID.arbitrumOne,
        feeTokenAssetID: AssetID.arbitrumOneETH,
        name: "Arbitrum One",
        failsafeRPCServerURL: URL(string: "https://arbitrum.llamarpc.com")!
    )
    
    static let opMainnet = Web3Chain.evm(
        chainID: 10,
        mixinChainID: ChainID.opMainnet,
        feeTokenAssetID: AssetID.opMainnetETH,
        name: "OP Mainnet",
        failsafeRPCServerURL: URL(string: "https://optimism.llamarpc.com")!
    )
    
    static let avalancheCChain = Web3Chain.evm(
        chainID: 43114,
        mixinChainID: ChainID.avalancheCChain,
        feeTokenAssetID: AssetID.avalancheCAVAX,
        name: "Avalanche",
        failsafeRPCServerURL: URL(string: "https://api.avax.network/ext/bc/C/rpc")!
    )
    
    static let solana = Web3Chain.solana(
        reference: "4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ",
        mixinChainID: ChainID.solana,
        feeTokenAssetID: AssetID.sol,
        name: "Solana",
        failsafeRPCServerURL: URL(string: "https://api.mainnet-beta.solana.com")!
    )
    
#if DEBUG
    static let solanaDevnet = Web3Chain.solana(
        reference: "EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
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
                        guard let dapps = dapps[chain.chainID] else {
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
