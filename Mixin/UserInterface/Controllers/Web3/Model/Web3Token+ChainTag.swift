import Foundation
import MixinServices

extension Web3Token {
    
    public var chainTag: String? {
        switch chainID {
        case Web3Chain.solana.web3ChainID:
            "Solana"
        case Web3Chain.ethereum.web3ChainID where assetKey != AssetKey.eth:
            "ERC-20"
        default:
            nil
        }
    }
    
}
