import Foundation
import MixinServices

extension Chain {
    
    var depositSupporting: String {
        switch chainId {
        case ChainID.eos, ChainID.ripple, ChainID.mobilecoin,
            ChainID.ton, ChainID.solana,
            ChainID.polygon, ChainID.bnbSmartChain, ChainID.base,
            ChainID.arbitrumOne, ChainID.opMainnet, ChainID.avalancheCChain,
            ChainID.hyperEVM, ChainID.xLayer, ChainID.robinhood:
            R.string.localizable.deposit_supporting_token_of_network(name)
        case ChainID.ethereum:
            R.string.localizable.deposit_tip_eth()
        case ChainID.tron:
            R.string.localizable.deposit_tip_trx()
        case ChainID.lightning:
            R.string.localizable.deposit_tip_lightning()
        default:
            R.string.localizable.deposit_supporting_single_token(symbol)
        }
    }
    
}
