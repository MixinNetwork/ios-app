import Foundation

public protocol OnChainToken: Token {
    
    var chainID: String { get }
    var assetKey: String { get }
    var chain: Chain? { get }
    var chainTag: String? { get }
    
}

extension OnChainToken {
    
    public var isEOSChain: Bool {
        chainID == ChainID.eos
    }
    
    public var isERC20: Bool {
        chainID == ChainID.ethereum
    }
    
    public var memoPossibility: WithdrawalMemoPossibility {
        WithdrawalMemoPossibility(rawValue: chain?.withdrawalMemoPossibility) ?? .possible
    }
    
    public var depositNetworkName: String? {
        switch chainID {
        case ChainID.ethereum:
            return "Ethereum (ERC-20)"
        case ChainID.avalancheXChain:
            return "Avalanche X-Chain"
        case ChainID.bnbBeaconChain:
            return "BNB Beacon Chain (BEP-2)"
        case ChainID.bnbSmartChain:
            return "BNB Smart Chain (BEP-20)"
        case ChainID.tron:
            return assetKey.isDigitsOnly ? "Tron (TRC-10)" : "Tron (TRC-20)"
        case ChainID.bitShares:
            return "BitShares"
        default:
            return chain?.name
        }
    }
    
}
