import Foundation
import OrderedCollections
import MixinServices

struct WatchingAddresses {
    
    let addresses: OrderedDictionary<Web3Chain.Kind, String>
    let prettyFormatted: String
    
    init(addresses: [Web3Address]) {
        var bitcoinAddress: String?
        var evmAddress: String?
        var solanaAddress: String?
        for address in addresses {
            guard let chain = Web3Chain.chain(chainID: address.chainID) else {
                continue
            }
            switch chain.kind {
            case .bitcoin:
                if bitcoinAddress == nil {
                    bitcoinAddress = address.destination
                }
            case .evm:
                if evmAddress == nil {
                    evmAddress = address.destination
                }
            case .solana:
                if solanaAddress == nil {
                    solanaAddress = address.destination
                }
            }
            if evmAddress != nil && solanaAddress != nil {
                break
            }
        }
        
        var orderedAddresses: OrderedDictionary<Web3Chain.Kind, String> = [:]
        if let bitcoinAddress {
            orderedAddresses[.bitcoin] = bitcoinAddress
        }
        if let evmAddress {
            orderedAddresses[.evm] = evmAddress
        }
        if let solanaAddress {
            orderedAddresses[.solana] = solanaAddress
        }
        
        self.addresses = orderedAddresses
        self.prettyFormatted = orderedAddresses
            .values
            .map { destination in
                TextTruncation.truncateMiddle(string: destination, prefixCount: 6, suffixCount: 4)
            }
            .joined(separator: ", ")
    }
    
}
