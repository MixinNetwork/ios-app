import Foundation
import MixinServices

extension Chain {
    
    var depositSupporting: String {
        switch chainId {
        case ChainID.eos, ChainID.solana, ChainID.bnbSmartChain, ChainID.base, ChainID.ripple, ChainID.polygon, ChainID.mobilecoin:
            R.string.localizable.deposit_supporting_token_of_network(name)
        case ChainID.ethereum:
            R.string.localizable.deposit_tip_eth()
        case ChainID.tron:
            R.string.localizable.deposit_tip_trx()
        default:
            R.string.localizable.deposit_supporting_single_token(symbol)
        }
    }
    
}
